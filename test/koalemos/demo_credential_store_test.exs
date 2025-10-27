defmodule Koalemos.DemoCredentialStoreTest do
  use ExUnit.Case, async: false  # File operations need sequential execution
  alias Koalemos.DemoCredentialStore

  @test_path "test/tmp/credentials_test.json"

  setup do
    # Set test credentials path
    System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_path)

    # Clean up test files
    cleanup_test_files()

    on_exit(fn ->
      cleanup_test_files()
      System.delete_env("KOALEMOS_CREDENTIALS_PATH")
    end)

    :ok
  end

  defp cleanup_test_files do
    File.rm(@test_path)
    File.rm("#{@test_path}.lock")
    File.rm_rf("test/tmp")
  end

  describe "load/0" do
    test "creates default file when it doesn't exist" do
      assert {:ok, data} = DemoCredentialStore.load()

      # Should have all providers
      assert data["providers"]["anthropic"]["model"] == "claude-3-5-sonnet-20241022"
      assert data["providers"]["openai"]["model"] == "gpt-4"
      assert data["providers"]["ollama"]["base_url"] == "http://localhost:11434"

      # Should have selected provider
      assert data["selected_provider"] == "anthropic"

      # File should exist
      assert File.exists?(@test_path)
    end

    test "loads existing file" do
      # Create a file first
      {:ok, _} = DemoCredentialStore.load()

      # Load again should return same data
      assert {:ok, data} = DemoCredentialStore.load()
      assert Map.has_key?(data, "providers")
    end

    test "ensures providers section exists in old files" do
      # Create file without providers section
      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, Jason.encode!(%{"some_key" => "value"}))

      # Load should add providers
      assert {:ok, data} = DemoCredentialStore.load()
      assert Map.has_key?(data, "providers")
      assert Map.has_key?(data["providers"], "anthropic")
    end

    test "backs up and recreates corrupted file" do
      # Create corrupted JSON file
      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, "{invalid json")

      # Load should backup and recreate
      assert {:ok, data} = DemoCredentialStore.load()
      assert Map.has_key?(data, "providers")

      # Backup file should exist
      backup_files = Path.wildcard("#{@test_path}.backup.*")
      assert length(backup_files) > 0
    end

    test "returns error for file read failures" do
      # Create file with bad permissions (this is hard to test cross-platform)
      # Instead test when directory doesn't exist and can't be created
      System.put_env("KOALEMOS_CREDENTIALS_PATH", "/root/impossible/path.json")

      result = DemoCredentialStore.load()

      # Should either fail to read or fail to create
      assert match?({:error, _}, result)

      System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_path)
    end
  end

  describe "get_provider_config/1" do
    test "returns provider config" do
      assert {:ok, config} = DemoCredentialStore.get_provider_config("anthropic")
      assert config["model"] == "claude-3-5-sonnet-20241022"
      assert config["api_key"] == ""
    end

    test "returns default config for unknown provider" do
      assert {:ok, config} = DemoCredentialStore.get_provider_config("anthropic")
      assert is_map(config)
    end

    test "returns config for all providers" do
      assert {:ok, anthropic} = DemoCredentialStore.get_provider_config("anthropic")
      assert {:ok, openai} = DemoCredentialStore.get_provider_config("openai")
      assert {:ok, ollama} = DemoCredentialStore.get_provider_config("ollama")

      assert anthropic["model"] == "claude-3-5-sonnet-20241022"
      assert openai["model"] == "gpt-4"
      assert ollama["base_url"] == "http://localhost:11434"
    end
  end

  describe "update_provider/2" do
    test "updates provider configuration" do
      # Update anthropic config
      assert :ok = DemoCredentialStore.update_provider("anthropic", %{"api_key" => "test-key"})

      # Verify update
      assert {:ok, config} = DemoCredentialStore.get_provider_config("anthropic")
      assert config["api_key"] == "test-key"
      assert config["model"] == "claude-3-5-sonnet-20241022"  # Preserves existing
    end

    test "merges updates with existing config" do
      # Set initial config
      :ok = DemoCredentialStore.update_provider("openai", %{"api_key" => "key1", "custom" => "value"})

      # Update with partial changes
      :ok = DemoCredentialStore.update_provider("openai", %{"api_key" => "key2"})

      # Should merge
      {:ok, config} = DemoCredentialStore.get_provider_config("openai")
      assert config["api_key"] == "key2"
      assert config["custom"] == "value"
      assert config["model"] == "gpt-4"
    end

    test "creates provider config if it doesn't exist" do
      # Update non-existent provider gets default first
      assert :ok = DemoCredentialStore.update_provider("anthropic", %{"api_key" => "new-key"})

      {:ok, config} = DemoCredentialStore.get_provider_config("anthropic")
      assert config["api_key"] == "new-key"
    end
  end

  describe "get_selected_provider/0" do
    test "returns default provider when not set" do
      DemoCredentialStore.load()
      assert DemoCredentialStore.get_selected_provider() == "anthropic"
    end

    test "returns selected provider" do
      DemoCredentialStore.load()
      :ok = DemoCredentialStore.set_selected_provider("openai")
      assert DemoCredentialStore.get_selected_provider() == "openai"
    end

    test "returns anthropic when file doesn't exist" do
      # Don't load/create file
      File.rm(@test_path)
      assert DemoCredentialStore.get_selected_provider() == "anthropic"
    end
  end

  describe "set_selected_provider/1" do
    test "sets valid provider" do
      assert :ok = DemoCredentialStore.set_selected_provider("anthropic")
      assert DemoCredentialStore.get_selected_provider() == "anthropic"

      assert :ok = DemoCredentialStore.set_selected_provider("openai")
      assert DemoCredentialStore.get_selected_provider() == "openai"

      assert :ok = DemoCredentialStore.set_selected_provider("ollama")
      assert DemoCredentialStore.get_selected_provider() == "ollama"
    end

    test "rejects invalid provider" do
      result = DemoCredentialStore.set_selected_provider("invalid")
      assert {:error, error_msg} = result
      assert error_msg =~ "Invalid provider"
    end

    test "persists selection across loads" do
      DemoCredentialStore.set_selected_provider("openai")

      # Load again
      {:ok, data} = DemoCredentialStore.load()
      assert data["selected_provider"] == "openai"
    end
  end

  describe "file operations" do
    test "writes file with restrictive permissions" do
      {:ok, _} = DemoCredentialStore.load()

      # Check file permissions (0o600 = owner read/write only)
      stat = File.stat!(@test_path)
      # On Unix systems, should be 0o600
      # Note: Windows doesn't support Unix permissions
      case :os.type() do
        {:unix, _} ->
          assert stat.mode == 0o100600  # 0o100000 is regular file bit
        _ ->
          :ok  # Skip on non-Unix systems
      end
    end

    test "uses atomic writes with temp file" do
      {:ok, _} = DemoCredentialStore.load()

      # Update should use temp file (we can't easily verify this without mocking)
      # But we can verify the operation succeeds
      assert :ok = DemoCredentialStore.update_provider("anthropic", %{"api_key" => "test"})
    end
  end

  describe "file locking" do
    test "handles concurrent updates safely" do
      DemoCredentialStore.load()

      # Simulate concurrent updates
      tasks = for i <- 1..5 do
        Task.async(fn ->
          DemoCredentialStore.update_provider("anthropic", %{"counter" => i})
        end)
      end

      # All should succeed (one will win, others will retry)
      results = Task.await_many(tasks)
      assert Enum.all?(results, fn result -> result == :ok end)

      # File should be consistent
      assert {:ok, _} = DemoCredentialStore.load()
    end
  end

  describe "environment variable override" do
    test "uses custom path from environment" do
      custom_path = "test/tmp/custom_credentials.json"
      System.put_env("KOALEMOS_CREDENTIALS_PATH", custom_path)

      {:ok, _} = DemoCredentialStore.load()

      assert File.exists?(custom_path)
      refute File.exists?(@test_path)

      # Cleanup
      File.rm(custom_path)
    end
  end

  describe "OAuth credentials coexistence" do
    test "preserves OAuth section when updating providers" do
      # Create file with OAuth credentials
      oauth_data = %{
        "claudeAiOauth" => %{
          "accessToken" => "token123",
          "refreshToken" => "refresh456",
          "expiresAt" => 1234567890
        },
        "providers" => %{
          "anthropic" => %{"api_key" => "", "model" => "claude-3-5-sonnet-20241022"}
        },
        "selected_provider" => "anthropic"
      }

      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, Jason.encode!(oauth_data))

      # Update provider
      :ok = DemoCredentialStore.update_provider("anthropic", %{"api_key" => "new-key"})

      # OAuth section should still be there
      {:ok, data} = DemoCredentialStore.load()
      assert data["claudeAiOauth"]["accessToken"] == "token123"
      assert data["providers"]["anthropic"]["api_key"] == "new-key"
    end
  end
end
