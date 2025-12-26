defmodule CrucibleDeployment.Converters.TensorRTTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Converters.TensorRT

  test "converts to tensorrt" do
    source = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.bin")
    output = Path.join(System.tmp_dir!(), "model-#{System.unique_integer([:positive])}.trt")

    File.write!(source, "data")

    assert {:ok, ^output} = TensorRT.convert(source, :tensorrt, output_path: output)
    assert File.exists?(output)
  end

  test "reports supported formats" do
    assert [:tensorrt] = TensorRT.supported_formats()
  end
end
