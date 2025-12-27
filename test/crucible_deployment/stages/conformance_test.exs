defmodule CrucibleDeployment.Stages.ConformanceTest do
  @moduledoc """
  Conformance tests verifying all deployment stages implement
  the describe/1 contract correctly per the canonical schema specification.
  """
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Stages.{
    Deploy,
    Promote,
    Rollback
  }

  @stages [
    Deploy,
    Promote,
    Rollback
  ]

  describe "all deployment stages implement describe/1" do
    for stage <- @stages do
      test "#{inspect(stage)} has describe/1" do
        assert function_exported?(unquote(stage), :describe, 1)
      end

      test "#{inspect(stage)} returns valid schema" do
        schema = unquote(stage).describe(%{})
        assert is_atom(schema.name)
        assert is_binary(schema.description)
        assert is_list(schema.required)
        assert is_list(schema.optional)
        assert is_map(schema.types)
      end

      test "#{inspect(stage)} has types for all required fields" do
        schema = unquote(stage).describe(%{})

        for key <- schema.required do
          assert Map.has_key?(schema.types, key),
                 "Required field #{key} missing from types"
        end
      end

      test "#{inspect(stage)} has types for all optional fields" do
        schema = unquote(stage).describe(%{})

        for key <- schema.optional do
          assert Map.has_key?(schema.types, key),
                 "Optional field #{key} missing from types"
        end
      end

      test "#{inspect(stage)} has no overlap between required and optional" do
        schema = unquote(stage).describe(%{})

        overlap =
          MapSet.intersection(
            MapSet.new(schema.required),
            MapSet.new(schema.optional)
          )

        assert MapSet.size(overlap) == 0
      end
    end
  end

  describe "stage-specific schemas" do
    test "deploy has expected schema" do
      schema = Deploy.describe(%{})
      assert schema.name == :deploy
      assert :target in schema.optional
      assert :strategy in schema.optional
      assert {:enum, [:vllm, :tgi, :triton, :sagemaker, :kubernetes]} = schema.types.target
    end

    test "promote has expected schema" do
      schema = Promote.describe(%{})
      assert schema.name == :deployment_promote
    end

    test "rollback has expected schema" do
      schema = Rollback.describe(%{})
      assert schema.name == :rollback
    end
  end

  describe "type specifications are valid" do
    @primitive_types [:string, :integer, :float, :boolean, :atom, :map, :list, :module, :any]

    for stage <- @stages do
      test "#{inspect(stage)} has valid type specs" do
        schema = unquote(stage).describe(%{})

        for {key, type_spec} <- schema.types do
          assert valid_type_spec?(type_spec),
                 "Invalid type spec for :#{key}: #{inspect(type_spec)}"
        end
      end
    end

    defp valid_type_spec?(spec) when spec in @primitive_types, do: true
    defp valid_type_spec?({:struct, mod}) when is_atom(mod), do: true
    defp valid_type_spec?({:enum, values}) when is_list(values), do: true
    defp valid_type_spec?({:list, inner}), do: valid_type_spec?(inner)
    defp valid_type_spec?({:map, k, v}), do: valid_type_spec?(k) and valid_type_spec?(v)
    defp valid_type_spec?({:function, arity}) when is_integer(arity) and arity >= 0, do: true

    defp valid_type_spec?({:union, types}) when is_list(types),
      do: Enum.all?(types, &valid_type_spec?/1)

    defp valid_type_spec?({:tuple, types}) when is_list(types),
      do: Enum.all?(types, &valid_type_spec?/1)

    defp valid_type_spec?(_), do: false
  end
end
