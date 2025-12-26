defmodule CrucibleDeployment.Converters.GGUFTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Converters.GGUF

  test "converts to gguf" do
    source = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.bin")
    output = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.gguf")

    File.write!(source, "data")

    assert {:ok, ^output} = GGUF.convert(source, :gguf, output_path: output)
    assert File.exists?(output)
  end

  test "reports supported formats" do
    assert [:gguf] = GGUF.supported_formats()
  end
end
