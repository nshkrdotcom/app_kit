defmodule AppKit.Workspace.BoundaryGenerator do
  @moduledoc """
  Generates scaffold files for opaque-envelope DTOs and bridge mappers.
  """

  @spec generate(String.t(), Path.t(), keyword()) :: :ok | {:error, term()}
  def generate(name, output_root, opts \\ [])
      when is_binary(name) and is_binary(output_root) and is_list(opts) do
    case normalize_slug(name) do
      {:ok, slug} ->
        namespace = Keyword.get(opts, :module_namespace, "AppKit.Generated")
        dto_path = dto_path(output_root, namespace, slug)
        mapper_path = mapper_path(output_root, slug)
        mapper_test_path = mapper_test_path(output_root, slug)
        manifest_path = manifest_path(output_root, slug)

        dto_contents = dto_template(namespace, slug)
        mapper_contents = mapper_template(namespace, slug)
        mapper_test_contents = mapper_test_template(namespace, slug)

        :ok = write_file(dto_path, dto_contents)
        :ok = write_file(mapper_path, mapper_contents)
        :ok = write_file(mapper_test_path, mapper_test_contents)

        :ok =
          write_file(
            manifest_path,
            manifest_template(slug, dto_contents, mapper_contents, mapper_test_contents)
          )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_slug(name) do
    slug =
      name
      |> Macro.underscore()
      |> String.replace(~r/[^a-z0-9_]/, "")
      |> String.trim("_")

    if slug == "" do
      {:error, :invalid_boundary_name}
    else
      {:ok, slug}
    end
  end

  defp dto_path(output_root, namespace, slug) do
    Path.join([
      output_root,
      "core",
      "app_kit_core",
      "lib",
      namespace_path(namespace),
      "#{slug}.ex"
    ])
  end

  defp mapper_path(output_root, slug) do
    Path.join([
      output_root,
      "bridges",
      "mezzanine_bridge",
      "lib",
      "app_kit",
      "bridges",
      "mezzanine_bridge",
      "#{slug}_mapper.ex"
    ])
  end

  defp mapper_test_path(output_root, slug) do
    Path.join([
      output_root,
      "bridges",
      "mezzanine_bridge",
      "test",
      "app_kit",
      "bridges",
      "mezzanine_bridge",
      "#{slug}_mapper_test.exs"
    ])
  end

  defp manifest_path(output_root, slug) do
    Path.join([output_root, "generated_artifacts", "#{slug}_schema_registry.exs"])
  end

  defp namespace_path(namespace) do
    namespace
    |> Macro.underscore()
    |> String.replace(".", "/")
  end

  defp dto_template(namespace, slug) do
    module_name = Module.concat([namespace, Macro.camelize(slug)]) |> inspect()

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated opaque-envelope DTO scaffold.
      \"\"\"

      @enforce_keys [:schema_ref, :schema_version]
      defstruct [:schema_ref, :schema_version, payload: %{}, metadata: %{}]

      @type t :: %__MODULE__{
              schema_ref: String.t(),
              schema_version: non_neg_integer(),
              payload: map(),
              metadata: map()
            }

      @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_generated_boundary}
      def new(attrs) do
        attrs = Map.new(attrs)

        with schema_ref when is_binary(schema_ref) and byte_size(schema_ref) > 0 <-
               Map.get(attrs, :schema_ref),
             schema_version when is_integer(schema_version) and schema_version >= 0 <-
               Map.get(attrs, :schema_version),
             payload <- Map.get(attrs, :payload, %{}),
             true <- is_map(payload),
             metadata <- Map.get(attrs, :metadata, %{}),
             true <- is_map(metadata) do
          {:ok,
           %__MODULE__{
             schema_ref: schema_ref,
             schema_version: schema_version,
             payload: payload,
             metadata: metadata
           }}
        else
          _ -> {:error, :invalid_generated_boundary}
        end
      end
    end
    """
  end

  defp mapper_template(namespace, slug) do
    dto_module = Module.concat([namespace, Macro.camelize(slug)]) |> inspect()

    mapper_module =
      Module.concat(["AppKit.Bridges.MezzanineBridge", "#{Macro.camelize(slug)}Mapper"])
      |> inspect()

    """
    defmodule #{mapper_module} do
      @moduledoc \"\"\"
      Generated bridge mapper scaffold for opaque payload envelopes.
      \"\"\"

      alias #{dto_module}

      @spec from_payload(map()) :: {:ok, #{dto_module}.t()} | {:error, :invalid_generated_boundary}
      def from_payload(payload) when is_map(payload) do
        apply(dto_module(), :new, [%{
          schema_ref: Map.get(payload, :schema_ref, "generated/#{slug}"),
          schema_version: Map.get(payload, :schema_version, 1),
          payload: Map.get(payload, :payload, %{}),
          metadata: Map.get(payload, :metadata, %{})
        }])
      end

      def from_payload(_payload), do: {:error, :invalid_generated_boundary}

      defp dto_module, do: #{dto_module}
    end
    """
  end

  defp mapper_test_template(namespace, slug) do
    mapper_module =
      Module.concat(["AppKit.Bridges.MezzanineBridge", "#{Macro.camelize(slug)}Mapper"])
      |> inspect()

    dto_module = Module.concat([namespace, Macro.camelize(slug)]) |> inspect()

    """
    defmodule #{mapper_module}Test do
      use ExUnit.Case, async: true

      alias #{dto_module}
      alias #{mapper_module}

      test "generated mapper preserves the opaque payload envelope" do
        assert {:ok, %#{dto_module}{payload: %{"example" => true}}} =
                 Mapper.from_payload(%{
                   schema_ref: "generated/#{slug}",
                   schema_version: 1,
                   payload: %{"example" => true}
                 })
      end
    end
    """
  end

  defp manifest_template(slug, dto_contents, mapper_contents, mapper_test_contents) do
    manifest = %{
      contract_name: "AppKit.SchemaRegistryEntry.v1",
      schema_name: slug,
      schema_version: 1,
      dto_module: "AppKit.Generated.#{Macro.camelize(slug)}",
      generator_command: "mix app_kit.gen.boundary #{slug}",
      owner_repo: "app_kit",
      replacement_version_policy: "big_bang_no_legacy",
      generated_artifacts: %{
        dto_hash: sha256(dto_contents),
        mapper_hash: sha256(mapper_contents),
        mapper_test_hash: sha256(mapper_test_contents)
      }
    }

    """
    # Generated by `mix app_kit.gen.boundary #{slug}`.
    # This manifest is deterministic release evidence for the AppKit schema registry.
    #{inspect(manifest, pretty: true, limit: :infinity)}
    """
  end

  defp sha256(contents) do
    :crypto.hash(:sha256, contents)
    |> Base.encode16(case: :lower)
  end

  defp write_file(path, contents) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, contents)
    :ok
  end
end
