defmodule AppKit.OperatorConsole do
  @moduledoc """
  Operator console shell over AppKit DTOs and bounded trace export refs.
  """

  alias AppKit.Web.Components

  defmodule Session do
    @moduledoc "Authorized operator console session."
    @type t :: %__MODULE__{
            session_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            operator_ref: String.t(),
            trace_ref: String.t(),
            release_manifest_ref: String.t()
          }

    @enforce_keys [
      :session_ref,
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :operator_ref,
      :trace_ref,
      :release_manifest_ref
    ]
    defstruct @enforce_keys
  end

  defmodule ConsoleView do
    @moduledoc "Operator console render state."
    @type t :: %__MODULE__{
            console_ref: String.t(),
            tenant_ref: String.t(),
            section_count: non_neg_integer(),
            sections: %{atom() => map()},
            components: [map()],
            redaction_posture: String.t(),
            data_access_posture: String.t()
          }

    @enforce_keys [
      :console_ref,
      :tenant_ref,
      :section_count,
      :sections,
      :components,
      :redaction_posture,
      :data_access_posture
    ]
    defstruct @enforce_keys
  end

  @section_names [
    :adaptive_controls,
    :memory,
    :prompts,
    :guards,
    :replay,
    :evals,
    :costs,
    :connectors,
    :skills,
    :hive
  ]
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt_body,
    :memory_body,
    :provider_payload,
    :provider_response,
    :eval_payload,
    :credential,
    :authorization_header,
    :token,
    :secret,
    :private_state,
    :agent_message_body,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt_body",
    "memory_body",
    "provider_payload",
    "provider_response",
    "eval_payload",
    "credential",
    "authorization_header",
    "token",
    "secret",
    "private_state",
    "agent_message_body"
  ]

  @spec authorize(map()) :: {:ok, Session.t()} | {:error, term()}
  def authorize(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         :ok <-
           required_strings(attrs, [
             :session_ref,
             :tenant_ref,
             :authority_ref,
             :installation_ref,
             :operator_ref,
             :trace_ref,
             :release_manifest_ref
           ]),
         :ok <- operator_allowed(attrs) do
      {:ok,
       %Session{
         session_ref: fetch!(attrs, :session_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         operator_ref: fetch!(attrs, :operator_ref),
         trace_ref: fetch!(attrs, :trace_ref),
         release_manifest_ref: fetch!(attrs, :release_manifest_ref)
       }}
    end
  end

  def authorize(_attrs), do: {:error, :invalid_operator_console_session}

  @spec render(Session.t(), map()) :: {:ok, ConsoleView.t()} | {:error, term()}
  def render(%Session{} = session, sections) when is_map(sections) do
    with :ok <- reject_raw(sections),
         :ok <- Components.reject_raw_assigns(sections),
         :ok <- known_sections(sections),
         :ok <- tenant_match(session, sections),
         {:ok, section_views} <- section_views(session, sections),
         {:ok, components} <- components(session) do
      {:ok,
       %ConsoleView{
         console_ref: "operator-console://" <> session.session_ref,
         tenant_ref: session.tenant_ref,
         section_count: map_size(section_views),
         sections: section_views,
         components: components,
         redaction_posture: "dto_and_bounded_exports_only",
         data_access_posture: "app_kit_dtos_no_lower_store_imports"
       }}
    end
  end

  def render(%Session{}, _sections), do: {:error, :invalid_operator_console_sections}

  defp section_views(session, sections) do
    Enum.reduce_while(sections, {:ok, %{}}, fn {name, rows}, {:ok, acc} ->
      with {:ok, safe_rows} <- rows(rows),
           {:ok, table} <-
             Components.projection_table(%{
               table_ref:
                 "operator-console://" <> session.session_ref <> "/" <> Atom.to_string(name),
               tenant_ref: session.tenant_ref,
               columns: ["ref", "status"],
               rows: safe_rows
             }) do
        {:cont, {:ok, Map.put(acc, name, table)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp rows(rows) when is_list(rows), do: {:ok, Enum.map(rows, &normalize_row/1)}
  defp rows(_rows), do: {:error, :invalid_operator_console_rows}

  defp normalize_row(%_{} = struct), do: struct |> Map.from_struct() |> normalize_row()
  defp normalize_row(%{} = map), do: Map.take(map, Map.keys(map))
  defp normalize_row(other), do: %{ref: inspect(other), status: "unknown"}

  defp components(session) do
    with {:ok, tenant} <- Components.ref_badge("Tenant", session.tenant_ref),
         {:ok, authority} <- Components.ref_badge("Authority", session.authority_ref),
         {:ok, trace} <- Components.ref_badge("Trace", session.trace_ref) do
      {:ok, [tenant, authority, trace]}
    end
  end

  defp known_sections(sections) do
    case Enum.find(Map.keys(sections), &(&1 not in @section_names)) do
      nil -> :ok
      section -> {:error, {:unknown_operator_console_section, section}}
    end
  end

  defp tenant_match(session, sections) do
    sections
    |> Enum.flat_map(fn {_section, rows} -> List.wrap(rows) end)
    |> Enum.find(&tenant_mismatch?(session.tenant_ref, &1))
    |> case do
      nil -> :ok
      _row -> {:error, :tenant_mismatched_operator_projection}
    end
  end

  defp tenant_mismatch?(tenant_ref, %_{} = struct),
    do: tenant_mismatch?(tenant_ref, Map.from_struct(struct))

  defp tenant_mismatch?(tenant_ref, %{} = row) do
    case fetch(row, :tenant_ref) do
      nil -> false
      ^tenant_ref -> false
      _other_tenant -> true
    end
  end

  defp tenant_mismatch?(_tenant_ref, _row), do: false

  defp operator_allowed(attrs) do
    if fetch(attrs, :operator_authorized?) == false do
      {:error, :operator_console_access_denied}
    else
      :ok
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_operator_console_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_operator_console_ref, field}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch!(attrs, field), do: fetch(attrs, field)

  defp fetch(attrs, field) do
    case Map.fetch(attrs, field) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(field))
    end
  end
end
