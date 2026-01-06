defmodule Koalemos.Lenses.PersonaLensTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.PersonaLens

  describe "provide_context/2 with tone dimension" do
    test "returns professional tone context" do
      state = %{context: %{}}
      config = %{tone: :professional}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [tone_block] = blocks

      assert tone_block.type == "text"
      assert tone_block.text =~ "Professional"
      assert tone_block.text =~ "formal"
      assert tone_block.text =~ "business"
    end

    test "returns casual tone context" do
      state = %{context: %{}}
      config = %{tone: :casual}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [tone_block] = blocks

      assert tone_block.type == "text"
      assert tone_block.text =~ "Casual"
      assert tone_block.text =~ "conversational"
    end

    test "returns friendly tone context" do
      state = %{context: %{}}
      config = %{tone: :friendly}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [tone_block] = blocks

      assert tone_block.type == "text"
      assert tone_block.text =~ "Friendly"
      assert tone_block.text =~ "warm"
    end

    test "returns empathetic tone context" do
      state = %{context: %{}}
      config = %{tone: :empathetic}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [tone_block] = blocks

      assert tone_block.type == "text"
      assert tone_block.text =~ "Empathetic"
      assert tone_block.text =~ "compassion"
    end

    test "skips unknown tone values" do
      state = %{context: %{}}
      config = %{tone: :unknown_tone}

      blocks = PersonaLens.provide_context(state, config)

      assert blocks == []
    end
  end

  describe "provide_context/2 with expertise dimension" do
    test "returns technical expertise context" do
      state = %{context: %{}}
      config = %{expertise: [:technical]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [expertise_block] = blocks

      assert expertise_block.type == "text"
      assert expertise_block.text =~ "Technical"
      assert expertise_block.text =~ "engineering"
    end

    test "returns creative expertise context" do
      state = %{context: %{}}
      config = %{expertise: [:creative]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [expertise_block] = blocks

      assert expertise_block.type == "text"
      assert expertise_block.text =~ "Creative"
      assert expertise_block.text =~ "innovative"
    end

    test "returns business expertise context" do
      state = %{context: %{}}
      config = %{expertise: [:business]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [expertise_block] = blocks

      assert expertise_block.type == "text"
      assert expertise_block.text =~ "Business"
      assert expertise_block.text =~ "strategic"
    end

    test "returns analytical expertise context" do
      state = %{context: %{}}
      config = %{expertise: [:analytical]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [expertise_block] = blocks

      assert expertise_block.type == "text"
      assert expertise_block.text =~ "Analytical"
      assert expertise_block.text =~ "systematic"
    end

    test "returns ux expertise context" do
      state = %{context: %{}}
      config = %{expertise: [:ux]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [expertise_block] = blocks

      assert expertise_block.type == "text"
      assert expertise_block.text =~ "User Experience"
      assert expertise_block.text =~ "user"
    end

    test "concatenates multiple expertise areas" do
      state = %{context: %{}}
      config = %{expertise: [:technical, :ux]}

      blocks = PersonaLens.provide_context(state, config)

      # Should have 2 blocks - one for each expertise area
      assert length(blocks) == 2

      # First block is technical
      assert Enum.at(blocks, 0).text =~ "Technical"

      # Second block is UX
      assert Enum.at(blocks, 1).text =~ "User Experience"
    end

    test "handles three expertise areas" do
      state = %{context: %{}}
      config = %{expertise: [:technical, :creative, :business]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 3
      assert Enum.at(blocks, 0).text =~ "Technical"
      assert Enum.at(blocks, 1).text =~ "Creative"
      assert Enum.at(blocks, 2).text =~ "Business"
    end

    test "skips unknown expertise values" do
      state = %{context: %{}}
      config = %{expertise: [:technical, :unknown_expertise, :ux]}

      blocks = PersonaLens.provide_context(state, config)

      # Should have 2 blocks - unknown is skipped
      assert length(blocks) == 2
      assert Enum.at(blocks, 0).text =~ "Technical"
      assert Enum.at(blocks, 1).text =~ "User Experience"
    end

    test "returns empty list for empty expertise list" do
      state = %{context: %{}}
      config = %{expertise: []}

      blocks = PersonaLens.provide_context(state, config)

      assert blocks == []
    end
  end

  describe "provide_context/2 with style dimension" do
    test "returns concise style context" do
      state = %{context: %{}}
      config = %{style: :concise}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [style_block] = blocks

      assert style_block.type == "text"
      assert style_block.text =~ "Concise"
      assert style_block.text =~ "brief"
    end

    test "returns detailed style context" do
      state = %{context: %{}}
      config = %{style: :detailed}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [style_block] = blocks

      assert style_block.type == "text"
      assert style_block.text =~ "Detailed"
      assert style_block.text =~ "thorough"
    end

    test "returns balanced style context" do
      state = %{context: %{}}
      config = %{style: :balanced}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [style_block] = blocks

      assert style_block.type == "text"
      assert style_block.text =~ "Balanced"
      assert style_block.text =~ "middle ground"
    end

    test "returns storytelling style context" do
      state = %{context: %{}}
      config = %{style: :storytelling}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      [style_block] = blocks

      assert style_block.type == "text"
      assert style_block.text =~ "Storytelling"
      assert style_block.text =~ "narrative"
    end

    test "skips unknown style values" do
      state = %{context: %{}}
      config = %{style: :unknown_style}

      blocks = PersonaLens.provide_context(state, config)

      assert blocks == []
    end
  end

  describe "provide_context/2 with combined dimensions" do
    test "combines tone + single expertise + style" do
      state = %{context: %{}}

      config = %{
        tone: :professional,
        expertise: [:technical],
        style: :balanced
      }

      blocks = PersonaLens.provide_context(state, config)

      # Should have 3 blocks total
      assert length(blocks) == 3

      # Tone block
      assert Enum.at(blocks, 0).text =~ "Professional"

      # Expertise block
      assert Enum.at(blocks, 1).text =~ "Technical"

      # Style block
      assert Enum.at(blocks, 2).text =~ "Balanced"
    end

    test "combines tone + multiple expertise + style" do
      state = %{context: %{}}

      config = %{
        tone: :friendly,
        expertise: [:creative, :ux],
        style: :storytelling
      }

      blocks = PersonaLens.provide_context(state, config)

      # Should have 4 blocks: tone + 2 expertise + style
      assert length(blocks) == 4

      assert Enum.at(blocks, 0).text =~ "Friendly"
      assert Enum.at(blocks, 1).text =~ "Creative"
      assert Enum.at(blocks, 2).text =~ "User Experience"
      assert Enum.at(blocks, 3).text =~ "Storytelling"
    end

    test "works with partial config (only tone)" do
      state = %{context: %{}}
      config = %{tone: :casual}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      assert Enum.at(blocks, 0).text =~ "Casual"
    end

    test "works with partial config (only expertise)" do
      state = %{context: %{}}
      config = %{expertise: [:business, :analytical]}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 2
      assert Enum.at(blocks, 0).text =~ "Business"
      assert Enum.at(blocks, 1).text =~ "Analytical"
    end

    test "works with partial config (only style)" do
      state = %{context: %{}}
      config = %{style: :concise}

      blocks = PersonaLens.provide_context(state, config)

      assert length(blocks) == 1
      assert Enum.at(blocks, 0).text =~ "Concise"
    end
  end

  describe "provide_context/2 with empty or missing config" do
    test "returns empty list for empty config" do
      state = %{context: %{}}
      config = %{}

      blocks = PersonaLens.provide_context(state, config)

      assert blocks == []
    end

    test "handles nil state gracefully" do
      config = %{tone: :professional}

      # Should not crash with nil state
      blocks = PersonaLens.provide_context(nil, config)

      assert length(blocks) == 1
    end
  end
end
