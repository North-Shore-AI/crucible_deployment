defmodule CrucibleDeployment.Converters.Converter do
  @moduledoc """
  Behaviour for model format conversion.
  """

  @type conversion_opts :: [
          quantization: :q4_k_m | :q5_k_m | :q8_0 | :f16,
          output_path: Path.t()
        ]

  @callback convert(source_path :: Path.t(), target_format :: atom(), opts :: conversion_opts()) ::
              {:ok, output_path :: Path.t()} | {:error, term()}

  @callback supported_formats() :: [atom()]
end
