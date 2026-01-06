defmodule Koalemos.Log do
  @moduledoc """
  Domain-aware logging that respects LogConfig settings.

  Provides logging macros that only emit logs when the specified domain is enabled.
  This allows targeted debugging of specific parts of the system.

  ## Usage

  ```elixir
  require Koalemos.Log
  alias Koalemos.Log

  # Only logs if :context domain is enabled
  Log.debug(:context, "[Context] Building wireframe context")
  Log.info(:context, "[Context] Context size: \#{size} chars")
  ```

  ## Source Location

  All log entries include `:file` and `:line` metadata showing where the log
  was called from. Configure your logger format to display this:

  ```elixir
  config :logger, :console,
    format: "$time [$level] $message ($metadata)\\n",
    metadata: [:file, :line, :domain]
  ```

  ## Available Domains

  See `Koalemos.LogConfig` for the list of available domains.
  """

  require Logger

  @doc """
  Log a debug message if the domain is enabled.

  ## Examples

      Log.debug(:context, "Building context for routine")
      Log.debug(:llm, fn -> "Response: \#{inspect(response, limit: 500)}" end)
  """
  defmacro debug(domain, message_or_fun) do
    {file, line} = source_location(__CALLER__)

    quote do
      if Koalemos.LogConfig.enabled?(unquote(domain)) do
        Logger.debug(unquote(message_or_fun),
          file: unquote(file),
          line: unquote(line),
          domain: unquote(domain)
        )
      end
    end
  end

  @doc """
  Log an info message if the domain is enabled.
  """
  defmacro info(domain, message_or_fun) do
    {file, line} = source_location(__CALLER__)

    quote do
      if Koalemos.LogConfig.enabled?(unquote(domain)) do
        Logger.info(unquote(message_or_fun),
          file: unquote(file),
          line: unquote(line),
          domain: unquote(domain)
        )
      end
    end
  end

  @doc """
  Log a warning message if the domain is enabled.
  """
  defmacro warning(domain, message_or_fun) do
    {file, line} = source_location(__CALLER__)

    quote do
      if Koalemos.LogConfig.enabled?(unquote(domain)) do
        Logger.warning(unquote(message_or_fun),
          file: unquote(file),
          line: unquote(line),
          domain: unquote(domain)
        )
      end
    end
  end

  @doc """
  Log an error message if the domain is enabled.

  Note: Errors are typically always logged, but this allows filtering
  when debugging specific domains.
  """
  defmacro error(domain, message_or_fun) do
    {file, line} = source_location(__CALLER__)

    quote do
      if Koalemos.LogConfig.enabled?(unquote(domain)) do
        Logger.error(unquote(message_or_fun),
          file: unquote(file),
          line: unquote(line),
          domain: unquote(domain)
        )
      end
    end
  end

  # Extract short filename and line from caller environment
  defp source_location(caller) do
    file = caller.file |> Path.basename()
    line = caller.line
    {file, line}
  end
end
