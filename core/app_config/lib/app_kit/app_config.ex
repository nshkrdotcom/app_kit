defmodule AppKit.AppConfig do
  @moduledoc """
  Normalized app-facing config for AppKit surfaces.
  """

  @enforce_keys [:chat_surface?, :domain_surface?, :operator_surface?, :review_mode]
  defstruct [:chat_surface?, :domain_surface?, :operator_surface?, :review_mode]

  @type review_mode :: :interactive | :batched

  @type t :: %__MODULE__{
          chat_surface?: boolean(),
          domain_surface?: boolean(),
          operator_surface?: boolean(),
          review_mode: review_mode()
        }

  @spec normalize(map() | keyword() | nil) :: {:ok, t()} | {:error, atom()}
  def normalize(nil), do: normalize(%{})

  def normalize(attrs) do
    attrs = Map.new(attrs)
    review_mode = Map.get(attrs, :review_mode, :interactive)

    if review_mode in [:interactive, :batched] do
      {:ok,
       %__MODULE__{
         chat_surface?: Map.get(attrs, :chat_surface?, true),
         domain_surface?: Map.get(attrs, :domain_surface?, true),
         operator_surface?: Map.get(attrs, :operator_surface?, true),
         review_mode: review_mode
       }}
    else
      {:error, :invalid_app_config}
    end
  end
end
