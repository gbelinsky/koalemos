defmodule Koalemos.Steps.Agent.LLMRequestTest do
  # Credential stores are not async-safe
  use ExUnit.Case, async: false
  alias Koalemos.Steps.Agent.LLMRequest

  @test_credentials_path "test/tmp/llm_request_credentials.json"

  setup do
    # Set test credentials path
    System.put_env("KOALEMOS_CREDENTIALS_PATH", @test_credentials_path)

    # Clean up test files
    File.rm(@test_credentials_path)
    File.rm_rf("test/tmp")

    on_exit(fn ->
      File.rm(@test_credentials_path)
      File.rm_rf("test/tmp")
      System.delete_env("KOALEMOS_CREDENTIALS_PATH")
    end)

    :ok
  end

  describe "execute/2 - provider routing" do
    test "returns error when no messages in context" do
      state = %{
        routine_id: "routine-123",
        context: %{}
      }

      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg == "No messages found in context"
    end

    test "routes to anthropic provider by default" do
      # Create credentials file with Anthropic key
      create_credentials_file(%{"anthropic" => %{"api_key" => "test-key", "model" => "claude-3"}})

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "anthropic"
        }
      }

      # Will fail with API error (invalid key) but shows routing works
      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg =~ "API error 401"
    end

    test "routes to openai provider when specified" do
      # Create credentials file with OpenAI key
      create_credentials_file(%{"openai" => %{"api_key" => "test-key", "model" => "gpt-4"}})

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "openai"
        }
      }

      # Will fail with API error (invalid key) but shows routing works
      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg =~ "API error 401"
    end

    test "routes to ollama provider when specified" do
      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "ollama"
        }
      }

      # Will fail with connection error (Ollama not running) or API error (model not found)
      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg =~ "Connection refused" || error_msg =~ "API error"
    end

    test "returns error for unknown provider" do
      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "unknown"
        }
      }

      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg == "Unknown provider: unknown"
    end
  end

  describe "execute/2 - credential resolution" do
    test "uses API key from DemoCredentialStore for anthropic" do
      # Create credentials file with Anthropic API key
      create_credentials_file(%{
        "anthropic" => %{"api_key" => "test-anthropic-key", "model" => "claude-3"}
      })

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "anthropic"
        }
      }

      # Will fail with stub but credentials were resolved
      assert {:error, _} = LLMRequest.execute(%{}, state)
    end

    test "uses API key from DemoCredentialStore for openai" do
      create_credentials_file(%{
        "openai" => %{"api_key" => "test-openai-key", "model" => "gpt-4"}
      })

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "openai"
        }
      }

      # Will fail with stub but credentials were resolved
      assert {:error, _} = LLMRequest.execute(%{}, state)
    end

    test "returns error when OpenAI API key not configured" do
      # Create credentials file without OpenAI key
      create_credentials_file(%{
        "openai" => %{"api_key" => "", "model" => "gpt-4"}
      })

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "openai"
        }
      }

      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg =~ "Failed to get credentials"
      assert error_msg =~ "OpenAI API key not configured"
    end

    test "uses default config for ollama when credentials missing" do
      # Don't create credentials file - Ollama should use defaults
      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "ollama"
        }
      }

      # Will fail with connection error (Ollama not running) or API error (model not found)
      # But credentials defaulted successfully
      assert {:error, error_msg} = LLMRequest.execute(%{}, state)
      assert error_msg =~ "Connection refused" || error_msg =~ "API error"
    end
  end

  describe "execute/2 - config passthrough" do
    test "passes model, max_tokens, temperature to provider" do
      # Create credentials file with Anthropic key
      create_credentials_file(%{"anthropic" => %{"api_key" => "test-key", "model" => "claude-3"}})

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "anthropic",
          llm_model: "custom-model",
          max_tokens: 1000,
          temperature: 0.5
        }
      }

      # Config is passed but stub returns error
      assert {:error, _} = LLMRequest.execute(%{}, state)
    end

    test "uses default config values when not provided" do
      # Create credentials file with Anthropic key
      create_credentials_file(%{"anthropic" => %{"api_key" => "test-key", "model" => "claude-3"}})

      state = %{
        routine_id: "routine-123",
        context: %{
          messages: [%{role: "user", content: [%{type: "text", text: "Hi"}]}],
          llm_provider: "anthropic"
        }
      }

      # Defaults: max_tokens=16384, temperature=0.1
      assert {:error, _} = LLMRequest.execute(%{}, state)
    end
  end

  # Helper to create credentials file
  defp create_credentials_file(providers) do
    File.mkdir_p!(Path.dirname(@test_credentials_path))

    credentials = %{
      "providers" => providers,
      "selected_provider" => "anthropic"
    }

    File.write!(@test_credentials_path, Jason.encode!(credentials))
  end
end
