defmodule CrucibleDeployment.Utils do
  @moduledoc "Utility helpers for deployment operations."

  import Bitwise

  @doc """
  Generate a UUIDv4 string.
  """
  @spec generate_uuid() :: String.t()
  def generate_uuid do
    <<a1::32, a2::16, a3::16, a4::16, a5::48>> = :crypto.strong_rand_bytes(16)

    a3 = (a3 &&& 0x0FFF) ||| 0x4000
    a4 = (a4 &&& 0x3FFF) ||| 0x8000

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a1, a2, a3, a4, a5])
    |> List.to_string()
  end
end
