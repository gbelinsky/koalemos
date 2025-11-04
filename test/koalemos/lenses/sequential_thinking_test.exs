defmodule Koalemos.Lenses.SequentialThinkingTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.SequentialThinking

  describe "tools/0" do
    test "returns sequential_thinking tool definition" do
      tools = SequentialThinking.tools()

      assert length(tools) == 1
      [{module, tool_atom}] = tools

      assert module == SequentialThinking
      assert tool_atom == :sequential_thinking

      # Get the info for the tool
      tool_info = SequentialThinking.info(tool_atom)

      assert tool_info.name == "sequential_thinking"
      assert tool_info.description =~ "problem-solving"
      assert tool_info.input_schema.type == "object"
      assert length(tool_info.input_schema.required) == 4
    end
  end

  describe "execute/3 - basic thought progression" do
    test "first thought creates history" do
      state = %{}

      args = %{
        "thought" => "Breaking down the problem into steps",
        "thought_number" => 1,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      assert {result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      # Brief text result
      assert is_binary(result)
      assert result =~ "1/3"
      assert result =~ "Continue with next thought"

      # State updates
      assert Keyword.has_key?(lens_updates, :thought_history)
      assert Keyword.has_key?(lens_updates, :branches)

      history = Keyword.get(lens_updates, :thought_history)
      assert length(history) == 1
      assert hd(history).thought == "Breaking down the problem into steps"
      assert hd(history).thought_number == 1
    end

    test "subsequent thoughts append to history" do
      existing_history = [
        %{
          thought: "First thought",
          thought_number: 1,
          total_thoughts: 3,
          next_thought_needed: true,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        }
      ]

      state = %{lens_state: %{thought_history: existing_history, branches: %{}}}

      args = %{
        "thought" => "Second thought building on first",
        "thought_number" => 2,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      assert {_result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      history = Keyword.get(lens_updates, :thought_history)
      assert length(history) == 2
      assert Enum.at(history, 1).thought == "Second thought building on first"
    end

    test "final thought marks chain as complete" do
      state = %{}

      args = %{
        "thought" => "Final conclusion",
        "thought_number" => 3,
        "total_thoughts" => 3,
        "next_thought_needed" => false
      }

      assert {result, _lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      # Check result is a string indicating completion
      assert is_binary(result)
      assert result =~ "3/3"
      assert result =~ "complete"
    end
  end

  describe "execute/3 - dynamic total adjustment" do
    test "auto-adjusts total_thoughts when exceeded" do
      state = %{}

      args = %{
        "thought" => "Realized I need more steps",
        "thought_number" => 5,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      assert {result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      # Check result shows adjusted total
      assert is_binary(result)
      assert result =~ "5/5"

      # Total should be adjusted in history
      history = Keyword.get(lens_updates, :thought_history)
      assert hd(history).total_thoughts == 5
    end
  end

  describe "execute/3 - revisions" do
    test "marks revision and references original thought" do
      state = %{}

      args = %{
        "thought" => "Actually, let me reconsider step 2",
        "thought_number" => 4,
        "total_thoughts" => 5,
        "next_thought_needed" => true,
        "is_revision" => true,
        "revises_thought" => 2
      }

      assert {_result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      history = Keyword.get(lens_updates, :thought_history)
      thought = hd(history)

      assert thought.is_revision == true
      assert thought.revises_thought == 2
    end
  end

  describe "execute/3 - branching" do
    test "creates branch with branch_id" do
      state = %{context: %{lens_state: %{thought_history: [], branches: %{}}}}

      args = %{
        "thought" => "Exploring alternative approach",
        "thought_number" => 1,
        "total_thoughts" => 3,
        "next_thought_needed" => true,
        "branch_from_thought" => 2,
        "branch_id" => "alt_approach"
      }

      assert {_result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      branches = Keyword.get(lens_updates, :branches)
      assert Map.has_key?(branches, "alt_approach")
      assert length(branches["alt_approach"]) == 1
    end

    test "appends to existing branch" do
      existing_branches = %{
        "alt_approach" => [
          %{
            thought: "First thought in branch",
            thought_number: 1,
            total_thoughts: 3,
            next_thought_needed: true,
            is_revision: false,
            revises_thought: nil,
            branch_from_thought: 2,
            branch_id: "alt_approach",
            needs_more_thoughts: false
          }
        ]
      }

      state = %{lens_state: %{thought_history: [], branches: existing_branches}}

      args = %{
        "thought" => "Second thought in branch",
        "thought_number" => 2,
        "total_thoughts" => 3,
        "next_thought_needed" => true,
        "branch_from_thought" => 2,
        "branch_id" => "alt_approach"
      }

      assert {_result, lens_updates} = SequentialThinking.execute(:sequential_thinking, args, state)

      branches = Keyword.get(lens_updates, :branches)
      assert length(branches["alt_approach"]) == 2
    end
  end

  describe "execute/3 - validation" do
    test "rejects missing required field: thought" do
      state = %{}

      args = %{
        "thought_number" => 1,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      result = SequentialThinking.execute(:sequential_thinking, args, state)
      assert is_binary(result)
      assert result =~ "failed"
      assert result =~ "thought"
    end

    test "rejects empty thought" do
      state = %{}

      args = %{
        "thought" => "",
        "thought_number" => 1,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      result = SequentialThinking.execute(:sequential_thinking, args, state)
      assert is_binary(result)
      assert result =~ "failed"
      assert result =~ "thought"
    end

    test "rejects invalid thought_number" do
      state = %{}

      args = %{
        "thought" => "Test thought",
        "thought_number" => 0,
        "total_thoughts" => 3,
        "next_thought_needed" => true
      }

      result = SequentialThinking.execute(:sequential_thinking, args, state)
      assert is_binary(result)
      assert result =~ "failed"
      assert result =~ "thought_number"
    end

    test "rejects non-boolean next_thought_needed" do
      state = %{}

      args = %{
        "thought" => "Test thought",
        "thought_number" => 1,
        "total_thoughts" => 3,
        "next_thought_needed" => "yes"
      }

      result = SequentialThinking.execute(:sequential_thinking, args, state)
      assert is_binary(result)
      assert result =~ "failed"
      assert result =~ "next_thought_needed"
    end

    test "rejects unknown tool name" do
      state = %{}

      result = SequentialThinking.execute("unknown_tool", %{}, state)
      assert is_binary(result)
      assert result =~ "Unknown tool"
    end
  end

  describe "provide_context/2 - empty state" do
    test "returns empty list when no thoughts" do
      state = %{context: %{}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert blocks == []
    end

    test "returns empty list when thought_history is empty" do
      state = %{context: %{lens_state: %{thought_history: [], branches: %{}}}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert blocks == []
    end
  end

  describe "provide_context/2 - current chain" do
    test "shows only current chain after reset" do
      # First chain
      old_chain = [
        %{
          thought: "Old thought 1",
          thought_number: 1,
          total_thoughts: 2,
          next_thought_needed: true,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        },
        %{
          thought: "Old thought 2",
          thought_number: 2,
          total_thoughts: 2,
          next_thought_needed: false,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        }
      ]

      # New chain starts (thought_number == 1)
      full_history =
        old_chain ++
          [
            %{
              thought: "New chain starts here",
              thought_number: 1,
              total_thoughts: 3,
              next_thought_needed: true,
              is_revision: false,
              revises_thought: nil,
              branch_from_thought: nil,
              branch_id: nil,
              needs_more_thoughts: false
            },
            %{
              thought: "New chain second thought",
              thought_number: 2,
              total_thoughts: 3,
              next_thought_needed: true,
              is_revision: false,
              revises_thought: nil,
              branch_from_thought: nil,
              branch_id: nil,
              needs_more_thoughts: false
            }
          ]

      state = %{context: %{lens_state: %{thought_history: full_history, branches: %{}}}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert length(blocks) == 1
      [text_block] = blocks

      assert text_block.type == "text"
      # Should only show new chain, not old thoughts
      assert text_block.text =~ "New chain starts here"
      assert text_block.text =~ "New chain second thought"
      refute text_block.text =~ "Old thought 1"
      refute text_block.text =~ "Old thought 2"
    end

    test "shows revision marker in context" do
      history = [
        %{
          thought: "Original thought",
          thought_number: 1,
          total_thoughts: 3,
          next_thought_needed: true,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        },
        %{
          thought: "Revising previous step",
          thought_number: 2,
          total_thoughts: 3,
          next_thought_needed: true,
          is_revision: true,
          revises_thought: 1,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        }
      ]

      state = %{context: %{lens_state: %{thought_history: history, branches: %{}}}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert length(blocks) == 1
      [text_block] = blocks

      # Check for revision emoji
      assert text_block.text =~ "🔄"
    end

    test "shows continuation indicator when next_thought_needed" do
      history = [
        %{
          thought: "In progress...",
          thought_number: 1,
          total_thoughts: 3,
          next_thought_needed: true,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        }
      ]

      state = %{context: %{lens_state: %{thought_history: history, branches: %{}}}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert length(blocks) == 1
      [text_block] = blocks

      assert text_block.text =~ "[Thinking continues...]"
    end

    test "shows completion indicator when chain complete" do
      history = [
        %{
          thought: "Final thought",
          thought_number: 3,
          total_thoughts: 3,
          next_thought_needed: false,
          is_revision: false,
          revises_thought: nil,
          branch_from_thought: nil,
          branch_id: nil,
          needs_more_thoughts: false
        }
      ]

      state = %{context: %{lens_state: %{thought_history: history, branches: %{}}}}

      blocks = SequentialThinking.provide_context(state, %{})

      assert length(blocks) == 1
      [text_block] = blocks

      assert text_block.text =~ "[Thinking complete]"
    end
  end
end
