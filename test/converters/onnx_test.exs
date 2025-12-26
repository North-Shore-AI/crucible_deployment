defmodule CrucibleDeployment.Converters.ONNXTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Converters.ONNX

  test "converts to onnx" do
    source = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.bin")
    output = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.onnx")

    File.write!(source, "data")

    assert {:ok, ^output} = ONNX.convert(source, :onnx, output_path: output)
    assert File.exists?(output)
  end

  test "reports supported formats" do
    assert [:onnx] = ONNX.supported_formats()
  end
end
