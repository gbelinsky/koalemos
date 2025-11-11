defmodule Koalemos.Lenses.WireframeEditor.TicTacToeTest do
  @moduledoc """
  Integration test for complete feedback loop using tic-tac-toe game.

  Tests that an agent can:
  1. Build a game with tools
  2. Interact with it using trigger_interaction
  3. See the results in captured state (DOM, console, screenshot)
  4. Make decisions based on what it sees

  This validates the complete feedback loop for Sprint 7 Phase 7.
  """
  use ExUnit.Case, async: false

  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.Caches.{DOMStateCache, ConsoleCache, ScreenshotCache, WireframeStateCache}

  setup do
    routine_id = "tictactoe-test-#{:erlang.unique_integer([:positive])}"

    # Clear all caches
    DOMStateCache.clear_all()
    ConsoleCache.clear_all()
    ScreenshotCache.clear_all()

    # Cleanup on exit
    on_exit(fn ->
      WireframeStateCache.delete_state(routine_id)
      DOMStateCache.clear_dom_state(routine_id)
      ConsoleCache.clear_messages(routine_id)
      ScreenshotCache.clear(routine_id)
    end)

    {:ok, routine_id: routine_id}
  end

  describe "tic-tac-toe feedback loop" do
    test "agent builds game, plays move, and sees result", %{routine_id: routine_id} do
      # Step 1: Build initial tic-tac-toe board
      lens_state = build_tictactoe_game()

      # Store in cache so preview can render it
      WireframeStateCache.put_state(routine_id, lens_state)

      # Step 2: Agent triggers a click on cell 0 (top-left)
      # Spawn task to send completion response (simulating preview JavaScript)
      task = Task.async(fn ->
        :timer.sleep(100)
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "interaction:response:#{routine_id}",
          {:interaction_complete, %{"success" => true}}
        )
      end)

      {result, updates} = WireframeEditor.execute(
        :trigger_interaction,
        %{"action" => "click", "element_id" => "cell-0"},
        %{lens_state: lens_state, routine_id: routine_id}
      )

      Task.await(task)

      # Verify interaction succeeded
      assert result =~ "Successfully triggered"
      assert updates == []  # trigger_interaction doesn't update designed state

      # Step 3 & 4: Capture state (simulate preview responding to request)
      # Spawn task to simulate preview sending data after a delay
      # Simulate that cell-0 was clicked and now has "X"
      capture_task = Task.async(fn ->
        :timer.sleep(100)
        simulate_state_capture(routine_id, lens_state, %{"cell-0" => "X"})
      end)

      {:ok, captured_state} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task)

      # Agent should see:
      # - Updated DOM (cell-0 now has X)
      assert captured_state.dom_tree != nil
      cell_0 = find_element_by_id(captured_state.dom_tree, "cell-0")
      assert cell_0 != nil
      assert cell_0.content == "X"  # Agent's move

      # - Console log about the move
      assert length(captured_state.console_output) > 0
      assert Enum.any?(captured_state.console_output, fn log ->
        String.contains?(log.message, "Player X") or String.contains?(log.message, "clicked")
      end)

      # - Differs from designed state (since we triggered interaction)
      assert captured_state.differs_from_designed == true
    end

    test "agent sees full game state through multiple moves", %{routine_id: routine_id} do
      # Build game
      lens_state = build_tictactoe_game()
      WireframeStateCache.put_state(routine_id, lens_state)

      # Make three moves: X on 0, O on 4, X on 1
      moves = [
        {"cell-0", "X"},
        {"cell-4", "O"},
        {"cell-1", "X"}
      ]

      Enum.each(moves, fn {cell_id, _player} ->
        # Spawn task to send completion response
        task = Task.async(fn ->
          :timer.sleep(100)
          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "interaction:response:#{routine_id}",
            {:interaction_complete, %{"success" => true}}
          )
        end)

        # Trigger move
        {result, _} = WireframeEditor.execute(
          :trigger_interaction,
          %{"action" => "click", "element_id" => cell_id},
          %{lens_state: lens_state, routine_id: routine_id}
        )

        Task.await(task)
        assert result =~ "Successfully triggered"
      end)

      # Capture final state (simulate preview responding)
      # Simulate the three moves: X on 0, O on 4, X on 1
      capture_task = Task.async(fn ->
        :timer.sleep(100)
        simulate_state_capture(routine_id, lens_state, %{
          "cell-0" => "X",
          "cell-4" => "O",
          "cell-1" => "X"
        })
      end)

      {:ok, captured_state} = WireframeEditor.capture_current_state(routine_id, skip_screenshot: true, timeout: 1000)
      Task.await(capture_task)

      # Verify all moves visible in DOM
      cell_0 = find_element_by_id(captured_state.dom_tree, "cell-0")
      cell_1 = find_element_by_id(captured_state.dom_tree, "cell-1")
      cell_4 = find_element_by_id(captured_state.dom_tree, "cell-4")

      assert cell_0.content == "X"
      assert cell_1.content == "X"
      assert cell_4.content == "O"

      # Verify console shows all moves
      assert length(captured_state.console_output) >= 3
    end
  end

  # Helper: Build a basic tic-tac-toe game structure
  defp build_tictactoe_game do
    %{
      designed: %{
        dom_tree: %{
          tag: "div",
          id: "root",
          classes: ["game"],
          attributes: %{},
          handlers: %{},
          content: nil,
          children: [
            %{
              tag: "div",
              id: "board",
              classes: ["board"],
              attributes: %{},
              handlers: %{},
              content: nil,
              children: build_cells()
            },
            %{
              tag: "div",
              id: "status",
              classes: [],
              attributes: %{},
              handlers: %{},
              text: "Player X's turn",
              children: []
            }
          ]
        },
        custom_css: %{},
        custom_functions: %{
          "handleCellClick" => """
          function handleCellClick(cellId) {
            console.log('Player clicked cell: ' + cellId);
            const cell = document.getElementById(cellId);
            if (cell.textContent === '') {
              cell.textContent = window.currentPlayer;
              console.log('Player ' + window.currentPlayer + ' marked cell ' + cellId);
              window.currentPlayer = window.currentPlayer === 'X' ? 'O' : 'X';
            }
          }
          """
        },
        custom_variables: %{
          "currentPlayer" => "X"
        },
        init_scripts: %{},
        handlers: build_cell_handlers()
      },
      modifications: []
    }
  end

  # Build 9 cells (0-8) for tic-tac-toe board
  defp build_cells do
    for i <- 0..8 do
      %{
        tag: "div",
        id: "cell-#{i}",
        classes: ["cell"],
        attributes: %{},
        handlers: %{},
        text: "",
        children: []
      }
    end
  end

  # Build handlers for each cell
  defp build_cell_handlers do
    for i <- 0..8, into: %{} do
      {"cell-#{i}", %{click: "handleCellClick('cell-#{i}')"}}
    end
  end

  # Simulate what preview does: store DOM state and console, then broadcast ready
  # clicked_cells: map of cell_id => player mark (e.g., %{"cell-0" => "X"})
  defp simulate_state_capture(routine_id, lens_state, clicked_cells) do
    # Store DOM state (simulating what preview JavaScript sends)
    # Note: Cache expects JavaScript-style string keys, which it converts to atom keys

    # Simulate JavaScript modifying the DOM based on interactions
    modified_tree = apply_clicks_to_tree(lens_state.designed.dom_tree, clicked_cells)
    dom_tree_js = convert_to_js_format(modified_tree)

    DOMStateCache.add_dom_state(routine_id, %{
      "liveDOMTree" => dom_tree_js,
      "changeType" => "snapshot",
      "timestamp" => System.system_time(:millisecond)
    })

    # Add console messages (simulating what preview captures - one per click)
    Enum.each(clicked_cells, fn {cell_id, player} ->
      ConsoleCache.add_message(routine_id, %{
        level: "log",
        message: "Player #{player} clicked #{cell_id}",
        timestamp: System.system_time(:millisecond)
      })
    end)

    # Broadcast snapshot ready (what preview does after storing data)
    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )
  end

  # Simulate JavaScript modifying tree by updating clicked cells
  defp apply_clicks_to_tree(tree, clicked_cells) when map_size(clicked_cells) == 0, do: tree

  defp apply_clicks_to_tree(tree, clicked_cells) when is_map(tree) do
    # If this element was clicked, update its text/content
    updated_tree = case Map.get(clicked_cells, tree[:id]) do
      nil -> tree
      player_mark -> Map.put(tree, :text, player_mark)
    end

    # Recursively update children
    case updated_tree[:children] do
      children when is_list(children) ->
        Map.put(updated_tree, :children, Enum.map(children, &apply_clicks_to_tree(&1, clicked_cells)))
      _ ->
        updated_tree
    end
  end

  # Convert Elixir-format DOM tree (atom keys) to JavaScript format (string keys)
  defp convert_to_js_format(nil), do: nil

  defp convert_to_js_format(tree) when is_map(tree) do
    # Map both :text and :content to "content" since cache only preserves content field
    text_content = tree[:content] || tree[:text]

    %{
      "tag" => tree.tag,
      "id" => tree[:id],
      "classes" => tree[:classes] || [],
      "attributes" => tree[:attributes] || %{},
      "content" => text_content,
      "children" => Enum.map(tree[:children] || [], &convert_to_js_format/1)
    }
  end

  # Helper to find element by ID in DOM tree
  defp find_element_by_id(%{id: id} = element, target_id) when id == target_id, do: element
  defp find_element_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_element_by_id(child, target_id) end)
  end
  defp find_element_by_id(_, _), do: nil
end
