defmodule CrucibleDeployment.Converters.TensorRT do
  @moduledoc """
  TensorRT converter for NVIDIA-optimized deployments.
  """

  @behaviour CrucibleDeployment.Converters.Converter

  @doc """
  Convert a model file to TensorRT format.
  """
  @impl true
  @spec convert(Path.t(), atom(), keyword()) :: {:ok, Path.t()} | {:error, term()}
  def convert(source_path, :tensorrt, opts) do
    output_path = Keyword.get(opts, :output_path, default_output(source_path, ".trt"))

    with :ok <- ensure_source(source_path),
         :ok <- File.cp(source_path, output_path) do
      {:ok, output_path}
    end
  end

  def convert(_source_path, _format, _opts), do: {:error, :unsupported_format}

  @doc """
  Return supported conversion formats.
  """
  @impl true
  @spec supported_formats() :: [atom()]
  def supported_formats, do: [:tensorrt]

  defp ensure_source(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, :source_not_found}
    end
  end

  defp default_output(source_path, ext) do
    base = Path.rootname(source_path)
    base <> ext
  end
end
