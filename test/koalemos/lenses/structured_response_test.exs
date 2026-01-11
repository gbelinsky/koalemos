defmodule Koalemos.Lenses.StructuredResponseTest do
  use ExUnit.Case, async: true

  alias Koalemos.Lenses.StructuredResponse

  describe "provide_context/2" do
    test "returns empty list (lens provides no context)" do
      state = %{context: %{}}
      config = %{schema: %{name: %{type: :string}}}

      blocks = StructuredResponse.provide_context(state, config)

      assert blocks == []
    end
  end

  describe "tools/1" do
    test "returns respond tool tuple" do
      config = %{schema: %{}}

      tools = StructuredResponse.tools(config)

      assert tools == [{StructuredResponse, :respond}]
    end
  end

  describe "info/2 - basic schema types" do
    test "generates string field schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            name: %{type: :string, description: "User name"}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.name == "respond"
      assert info.input_schema.type == "object"
      assert info.input_schema.properties["name"] == %{type: "string", description: "User name"}
      assert "name" in info.input_schema.required
    end

    test "generates integer field schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            count: %{type: :integer, description: "Number of items"}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["count"] == %{type: "integer", description: "Number of items"}
    end

    test "generates number field schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            score: %{type: :number, description: "Score value"}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["score"] == %{type: "number", description: "Score value"}
    end

    test "generates boolean field schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            active: %{type: :boolean}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["active"] == %{type: "boolean"}
    end

    test "generates enum field schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            status: %{type: :enum, values: ["pending", "active", "done"]}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["status"] == %{
               type: "string",
               enum: ["pending", "active", "done"]
             }
    end
  end

  describe "info/2 - array types" do
    test "generates array of strings schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            tags: %{type: :array, items: :string}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["tags"] == %{
               type: "array",
               items: %{type: "string"}
             }
    end

    test "generates array of integers schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            scores: %{type: :array, items: :integer}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["scores"] == %{
               type: "array",
               items: %{type: "integer"}
             }
    end

    test "generates array with nested object items" do
      context = %{
        current_lens_config: %{
          schema: %{
            items: %{
              type: :array,
              items: %{
                name: %{type: :string},
                value: %{type: :integer}
              }
            }
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      items_schema = info.input_schema.properties["items"][:items]
      assert items_schema.type == "object"
      assert items_schema.properties["name"] == %{type: "string"}
      assert items_schema.properties["value"] == %{type: "integer"}
    end

    test "generates array without items (defaults to string)" do
      context = %{
        current_lens_config: %{
          schema: %{
            list: %{type: :array}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["list"] == %{
               type: "array",
               items: %{type: "string"}
             }
    end
  end

  describe "info/2 - map/object types" do
    test "generates map with nested properties" do
      context = %{
        current_lens_config: %{
          schema: %{
            metadata: %{
              type: :map,
              properties: %{
                version: %{type: :string},
                count: %{type: :integer}
              }
            }
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      metadata_schema = info.input_schema.properties["metadata"]
      assert metadata_schema.type == "object"
      assert metadata_schema.properties["version"] == %{type: "string"}
      assert metadata_schema.properties["count"] == %{type: "integer"}
    end

    test "generates free-form map without properties" do
      context = %{
        current_lens_config: %{
          schema: %{
            data: %{type: :map}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.properties["data"] == %{type: "object"}
    end
  end

  describe "info/2 - required fields" do
    test "marks fields as required by default" do
      context = %{
        current_lens_config: %{
          schema: %{
            name: %{type: :string},
            age: %{type: :integer}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert Enum.sort(info.input_schema.required) == ["age", "name"]
    end

    test "excludes optional fields from required" do
      context = %{
        current_lens_config: %{
          schema: %{
            name: %{type: :string},
            nickname: %{type: :string, required: false}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.required == ["name"]
    end

    test "handles all optional fields" do
      context = %{
        current_lens_config: %{
          schema: %{
            a: %{type: :string, required: false},
            b: %{type: :string, required: false}
          }
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema.required == []
    end
  end

  describe "info/2 - tool customization" do
    test "uses default tool name" do
      context = %{
        current_lens_config: %{
          schema: %{name: %{type: :string}}
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.name == "respond"
    end

    test "uses custom tool name" do
      context = %{
        current_lens_config: %{
          schema: %{name: %{type: :string}},
          tool_name: "submit_analysis"
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.name == "submit_analysis"
    end

    test "uses custom tool description" do
      context = %{
        current_lens_config: %{
          schema: %{name: %{type: :string}},
          tool_description: "Submit your analysis results"
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.description == "Submit your analysis results"
    end

    test "uses default description when not provided" do
      context = %{
        current_lens_config: %{
          schema: %{name: %{type: :string}}
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.description =~ "structured response"
    end
  end

  describe "info/2 - edge cases" do
    test "handles empty schema" do
      context = %{
        current_lens_config: %{
          schema: %{}
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema == %{type: "object", properties: %{}, required: []}
    end

    test "handles missing schema in config" do
      context = %{
        current_lens_config: %{}
      }

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema == %{type: "object", properties: %{}, required: []}
    end

    test "handles missing lens config" do
      context = %{}

      info = StructuredResponse.info(:respond, context)

      assert info.input_schema == %{type: "object", properties: %{}, required: []}
    end
  end

  describe "execute/3" do
    test "returns input in lens_state as structured_response" do
      input = %{"name" => "test", "count" => 42}
      context = %{}

      {message, lens_updates} = StructuredResponse.execute(:respond, input, context)

      assert message == "Response recorded."
      assert lens_updates == [structured_response: input]
    end

    test "preserves complex nested input" do
      input = %{
        "summary" => "Test summary",
        "items" => [%{"name" => "a"}, %{"name" => "b"}],
        "metadata" => %{"version" => "1.0"}
      }

      context = %{}

      {_message, lens_updates} = StructuredResponse.execute(:respond, input, context)

      assert lens_updates == [structured_response: input]
    end
  end

  describe "complex schema example" do
    test "generates full project analysis schema" do
      context = %{
        current_lens_config: %{
          schema: %{
            summary: %{type: :string, description: "Brief project summary"},
            language: %{type: :string, description: "Primary programming language"},
            complexity: %{type: :enum, values: ["low", "medium", "high"]},
            file_count: %{type: :integer},
            dependencies: %{type: :array, items: :string, required: false},
            metadata: %{
              type: :map,
              properties: %{
                version: %{type: :string},
                has_tests: %{type: :boolean}
              }
            }
          },
          tool_name: "submit_analysis",
          tool_description: "Submit the project analysis"
        }
      }

      info = StructuredResponse.info(:respond, context)

      assert info.name == "submit_analysis"
      assert info.description == "Submit the project analysis"

      schema = info.input_schema
      assert schema.type == "object"

      # Check properties
      assert schema.properties["summary"] == %{type: "string", description: "Brief project summary"}
      assert schema.properties["language"] == %{type: "string", description: "Primary programming language"}
      assert schema.properties["complexity"] == %{type: "string", enum: ["low", "medium", "high"]}
      assert schema.properties["file_count"] == %{type: "integer"}
      assert schema.properties["dependencies"] == %{type: "array", items: %{type: "string"}}

      metadata = schema.properties["metadata"]
      assert metadata.type == "object"
      assert metadata.properties["version"] == %{type: "string"}
      assert metadata.properties["has_tests"] == %{type: "boolean"}

      # Check required fields (dependencies is optional)
      required = Enum.sort(schema.required)
      assert required == ["complexity", "file_count", "language", "metadata", "summary"]
    end
  end
end
