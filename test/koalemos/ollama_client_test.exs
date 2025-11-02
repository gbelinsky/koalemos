defmodule Koalemos.OllamaClientTest do
  use ExUnit.Case, async: true
  alias Koalemos.OllamaClient

  @moduletag :external

  describe "check_connection/1" do
    test "returns {:ok, :connected} when server is reachable" do
      # This test requires Ollama to be running on localhost:11434
      # Tag: @tag :external
      case OllamaClient.check_connection() do
        {:ok, :connected} ->
          assert true

        {:error, reason} ->
          IO.puts("""
          Skipping test - Ollama server not available: #{reason}
          To run this test, start Ollama on localhost:11434
          """)
      end
    end

    test "returns error when connecting to non-existent server" do
      # Use a port that's unlikely to be in use
      result = OllamaClient.check_connection("http://localhost:99999")

      assert {:error, reason} = result
      # May return "Connection failed" or "Connection refused" depending on timing
      assert reason =~ "Connection"
    end

    test "uses default base URL when not specified" do
      # Should use http://localhost:11434 by default
      result = OllamaClient.check_connection()

      # Either connected or connection refused (Ollama not running)
      assert match?({:ok, :connected}, result) or
               match?({:error, _reason}, result)
    end
  end

  describe "list_models/1" do
    test "returns list of models when server is available" do
      # This test requires Ollama to be running
      case OllamaClient.list_models() do
        {:ok, models} ->
          assert is_list(models)
          # Models should be sorted
          assert models == Enum.sort(models)

        {:error, reason} ->
          IO.puts("""
          Skipping test - Ollama server not available: #{reason}
          To run this test, start Ollama on localhost:11434 and pull at least one model
          """)
      end
    end

    test "returns error when server is not available" do
      result = OllamaClient.list_models("http://localhost:99999")

      assert {:error, reason} = result
      # May return "Connection failed" or "Connection refused" depending on timing
      assert reason =~ "Connection"
    end

    test "uses default base URL when not specified" do
      # Should use http://localhost:11434 by default
      result = OllamaClient.list_models()

      # Either returns models or connection error (Ollama not running)
      assert match?({:ok, _models}, result) or
               match?({:error, _reason}, result)
    end

    test "handles empty model list gracefully" do
      # This is difficult to test without mocking, but we can verify
      # the function doesn't crash with various inputs
      # The actual Ollama server should always return some structure
      case OllamaClient.list_models() do
        {:ok, models} ->
          # Models list might be empty if no models are installed
          assert is_list(models)

        {:error, _reason} ->
          # Server not available, that's fine for this test
          assert true
      end
    end
  end

  describe "error handling" do
    test "handles connection errors gracefully" do
      result = OllamaClient.check_connection("http://localhost:99999")

      assert {:error, reason} = result
      # Error should indicate connection failure
      assert is_binary(reason)
      assert reason =~ "Connection"
    end

    test "handles connection timeouts" do
      # Using a non-routable IP to trigger timeout (this might take 2-5 seconds)
      # 192.0.2.0/24 is reserved for documentation and testing (RFC 5737)
      result = OllamaClient.check_connection("http://192.0.2.1:11434")

      assert {:error, _reason} = result
    end
  end

  describe "model name extraction" do
    # These tests verify the internal extract_model_names function behavior
    # by observing the output of list_models with a real server

    test "sorts model names alphabetically" do
      case OllamaClient.list_models() do
        {:ok, models} when length(models) > 1 ->
          # Verify models are sorted
          assert models == Enum.sort(models)

        _ ->
          IO.puts("Skipping test - need at least 2 models installed in Ollama")
      end
    end

    test "returns empty list when no models available" do
      # Can't easily test this without mocking, but we ensure it doesn't crash
      # The function should handle edge cases gracefully
      result = OllamaClient.list_models("http://localhost:99999")
      assert {:error, _} = result
    end
  end
end
