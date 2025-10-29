defmodule KoalemosWeb.StartSessionModalTest do
  use ExUnit.Case, async: true

  # Note: StartSessionModal is a LiveComponent that renders conditionally
  # based on @show prop. Full interactive testing would require LiveView
  # test helpers and is better covered by integration tests.

  test "component module exists" do
    assert Code.ensure_loaded?(KoalemosWeb.StartSessionModal)
  end
end
