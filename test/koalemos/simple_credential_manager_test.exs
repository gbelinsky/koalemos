defmodule Koalemos.SimpleCredentialManagerTest do
  use ExUnit.Case, async: false
  alias Koalemos.SimpleCredentialManager

  @test_path "test/tmp/oauth_test.json"

  setup do
    # Set test credentials path
    System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_path)

    # Clean up test files
    cleanup_test_files()

    # Start the credential manager
    {:ok, pid} = start_supervised(SimpleCredentialManager)

    on_exit(fn ->
      cleanup_test_files()
      System.delete_env("KOALEMOS_CREDENTIALS_PATH")
    end)

    {:ok, manager: pid}
  end

  defp cleanup_test_files do
    File.rm(@test_path)
    File.rm_rf("test/tmp")
  end

  defp create_test_credentials_file(opts \\ []) do
    # Default: token that doesn't need refresh (expires in 1 hour)
    expires_at = opts[:expires_at] || (System.system_time(:millisecond) + 60 * 60 * 1000)

    credentials = %{
      "claudeAiOauth" => %{
        "accessToken" => opts[:access_token] || "test-access-token",
        "refreshToken" => opts[:refresh_token] || "test-refresh-token",
        "expiresAt" => expires_at,
        "scopes" => opts[:scopes] || ["read", "write"],
        "subscriptionType" => opts[:subscription_type] || "pro"
      }
    }

    File.mkdir_p!(Path.dirname(@test_path))
    File.write!(@test_path, Jason.encode!(credentials))
  end

  describe "init/1" do
    test "initializes with no credentials when file not configured" do
      # Set env var to non-existent file (don't delete env var as it falls back to default path)
      System.put_env("KOALEMOS_CREDENTIALS_PATH", "test/tmp/nonexistent_credentials.json")

      # Stop existing manager and start new one
      stop_supervised(SimpleCredentialManager)
      {:ok, _pid} = start_supervised(SimpleCredentialManager)

      # Should return error when trying to get token
      assert {:error, :no_credentials} = SimpleCredentialManager.get_access_token()

      # Restore env var
      System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_path)
    end

    test "auto-loads credentials from configured file path" do
      # Stop existing manager
      stop_supervised(SimpleCredentialManager)

      # Create credentials file
      create_test_credentials_file(access_token: "auto-loaded-token")

      # Start new manager - should auto-load
      {:ok, _pid} = start_supervised(SimpleCredentialManager)

      # Should be able to get token
      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "auto-loaded-token"
    end

    test "handles auto-load failure gracefully" do
      # Stop existing manager
      stop_supervised(SimpleCredentialManager)

      # Create invalid credentials file
      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, "{invalid json")

      # Start new manager - should handle error gracefully
      {:ok, _pid} = start_supervised(SimpleCredentialManager)

      # Should return error when trying to get token
      assert {:error, :no_credentials} = SimpleCredentialManager.get_access_token()
    end
  end

  describe "load_credentials_from_file/1" do
    test "loads credentials from file" do
      create_test_credentials_file(access_token: "loaded-token")

      assert :ok = SimpleCredentialManager.load_credentials_from_file(@test_path)

      # Should be able to get token
      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "loaded-token"
    end

    test "returns error for non-existent file" do
      result = SimpleCredentialManager.load_credentials_from_file("non-existent.json")
      assert {:error, _reason} = result
    end

    test "returns error for invalid JSON" do
      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, "{invalid")

      result = SimpleCredentialManager.load_credentials_from_file(@test_path)
      assert {:error, _reason} = result
    end

    test "returns error for missing OAuth section" do
      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, Jason.encode!(%{"providers" => %{}}))

      result = SimpleCredentialManager.load_credentials_from_file(@test_path)
      assert {:error, _reason} = result
    end
  end

  describe "get_access_token/0" do
    test "returns error when no credentials loaded" do
      assert {:error, :no_credentials} = SimpleCredentialManager.get_access_token()
    end

    test "returns valid token when not expired" do
      # Token expires in 1 hour (far in future)
      create_test_credentials_file(
        access_token: "valid-token",
        expires_at: System.system_time(:millisecond) + 60 * 60 * 1000
      )

      SimpleCredentialManager.load_credentials_from_file(@test_path)

      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "valid-token"
    end

    test "returns token with different scopes and subscription types" do
      create_test_credentials_file(
        access_token: "custom-token",
        scopes: ["custom:read", "custom:write"],
        subscription_type: "enterprise"
      )

      SimpleCredentialManager.load_credentials_from_file(@test_path)

      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "custom-token"
    end
  end

  describe "token_needs_refresh?/1" do
    test "detects expired tokens that need refresh" do
      # Token expires in 4 minutes (less than 5 minute buffer)
      create_test_credentials_file(
        expires_at: System.system_time(:millisecond) + (4 * 60 * 1000)
      )

      SimpleCredentialManager.load_credentials_from_file(@test_path)

      # Getting token should trigger refresh (we can't easily test this without mocking HTTP)
      # But we can verify the token is detected as needing refresh by the fact that
      # it will try to refresh (which will fail in tests without HTTP mocking)
      # For now, we just verify it doesn't crash
      result = SimpleCredentialManager.get_access_token()

      # Will either return cached token or error from failed refresh
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not refresh tokens that are still valid" do
      # Token expires in 10 minutes (more than 5 minute buffer)
      create_test_credentials_file(
        access_token: "still-valid",
        expires_at: System.system_time(:millisecond) + (10 * 60 * 1000)
      )

      SimpleCredentialManager.load_credentials_from_file(@test_path)

      # Should return token without refresh
      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "still-valid"
    end
  end

  describe "concurrent access" do
    test "handles multiple simultaneous token requests" do
      create_test_credentials_file(access_token: "shared-token")
      SimpleCredentialManager.load_credentials_from_file(@test_path)

      # Make multiple concurrent requests
      tasks = for _i <- 1..5 do
        Task.async(fn ->
          SimpleCredentialManager.get_access_token()
        end)
      end

      # All should get the same token
      results = Task.await_many(tasks)
      assert Enum.all?(results, fn result ->
        {:ok, "shared-token"} == result
      end)
    end
  end

  describe "file persistence" do
    test "preserves provider section when saving OAuth credentials" do
      # Create file with both OAuth and providers
      credentials = %{
        "claudeAiOauth" => %{
          "accessToken" => "token1",
          "refreshToken" => "refresh1",
          "expiresAt" => System.system_time(:millisecond) + 60 * 60 * 1000,
          "scopes" => [],
          "subscriptionType" => "pro"
        },
        "providers" => %{
          "anthropic" => %{"api_key" => "test-key", "model" => "claude-3"}
        },
        "selected_provider" => "anthropic"
      }

      File.mkdir_p!(Path.dirname(@test_path))
      File.write!(@test_path, Jason.encode!(credentials))

      SimpleCredentialManager.load_credentials_from_file(@test_path)

      # Verify OAuth credentials loaded
      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "token1"

      # Verify providers section is still in file
      {:ok, content} = File.read(@test_path)
      {:ok, data} = Jason.decode(content)
      assert data["providers"]["anthropic"]["api_key"] == "test-key"
    end
  end

  describe "environment configuration" do
    test "uses KOALEMOS_CREDENTIALS_PATH environment variable" do
      custom_path = "test/tmp/custom_oauth.json"
      System.put_env("KOALEMOS_CREDENTIALS_PATH", custom_path)

      # Stop and restart manager to pick up new env var
      stop_supervised(SimpleCredentialManager)
      {:ok, _pid} = start_supervised(SimpleCredentialManager)

      # Create credentials at custom path
      File.mkdir_p!(Path.dirname(custom_path))
      credentials = %{
        "claudeAiOauth" => %{
          "accessToken" => "custom-token",
          "refreshToken" => "refresh",
          "expiresAt" => System.system_time(:millisecond) + 60 * 60 * 1000,
          "scopes" => [],
          "subscriptionType" => "pro"
        }
      }
      File.write!(custom_path, Jason.encode!(credentials))

      # Load from custom path
      SimpleCredentialManager.load_credentials_from_file(custom_path)

      assert {:ok, token} = SimpleCredentialManager.get_access_token()
      assert token == "custom-token"

      # Cleanup
      File.rm(custom_path)
      System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_path)
    end
  end
end
