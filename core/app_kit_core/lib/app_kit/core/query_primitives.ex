defmodule AppKit.Core.SortSpec do
  @moduledoc """
  Stable sorting contract for northbound paged reads.
  """

  alias AppKit.Core.Support

  @directions [:asc, :desc]
  @nulls [:first, :last]

  @enforce_keys [:field, :direction]
  defstruct [:field, :direction, nulls: nil]

  @type t :: %__MODULE__{
          field: String.t(),
          direction: :asc | :desc,
          nulls: :first | :last | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_sort_spec}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         field <- Map.get(attrs, :field),
         true <- Support.present_binary?(field),
         direction <- Map.get(attrs, :direction),
         true <- Support.enum?(direction, @directions),
         nulls <- Map.get(attrs, :nulls),
         true <- Support.optional_enum?(nulls, @nulls) do
      {:ok, %__MODULE__{field: field, direction: direction, nulls: nulls}}
    else
      _ -> {:error, :invalid_sort_spec}
    end
  end
end

defmodule AppKit.Core.FilterSet do
  @moduledoc """
  Stable filter envelope for northbound list and queue queries.
  """

  alias AppKit.Core.Support

  @modes [:and, :or]

  @enforce_keys [:clauses]
  defstruct [:clauses, mode: :and]

  @type t :: %__MODULE__{
          clauses: [map()],
          mode: :and | :or
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_filter_set}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         clauses <- Map.get(attrs, :clauses),
         true <- Support.list_of?(clauses, &is_map/1),
         mode <- Map.get(attrs, :mode, :and),
         true <- Support.enum?(mode, @modes) do
      {:ok, %__MODULE__{clauses: clauses, mode: mode}}
    else
      _ -> {:error, :invalid_filter_set}
    end
  end
end

defmodule AppKit.Core.PageRequest do
  @moduledoc """
  Stable page request contract for northbound reads.
  """

  alias AppKit.Core.{FilterSet, SortSpec, Support}

  @enforce_keys [:limit]
  defstruct [:limit, cursor: nil, sort: [], filters: nil]

  @type t :: %__MODULE__{
          limit: pos_integer(),
          cursor: String.t() | nil,
          sort: [SortSpec.t()],
          filters: FilterSet.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_page_request}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         limit <- Map.get(attrs, :limit),
         true <- Support.positive_integer?(limit),
         cursor <- Map.get(attrs, :cursor),
         true <- Support.optional_binary?(cursor),
         {:ok, sort_specs} <- build_sort_specs(Map.get(attrs, :sort, [])),
         {:ok, filters} <- Support.nested_struct(Map.get(attrs, :filters), FilterSet) do
      {:ok, %__MODULE__{limit: limit, cursor: cursor, sort: sort_specs, filters: filters}}
    else
      _ -> {:error, :invalid_page_request}
    end
  end

  defp build_sort_specs(sort_specs) when is_list(sort_specs) do
    Support.nested_structs(sort_specs, SortSpec)
  end

  defp build_sort_specs(_sort_specs), do: {:error, :invalid_nested}
end

defmodule AppKit.Core.PageResult do
  @moduledoc """
  Stable paged result envelope for northbound reads.
  """

  alias AppKit.Core.Support

  @enforce_keys [:entries]
  defstruct [:entries, next_cursor: nil, total_count: nil, has_more: nil, metadata: %{}]

  @type t :: %__MODULE__{
          entries: [term()],
          next_cursor: String.t() | nil,
          total_count: non_neg_integer() | nil,
          has_more: boolean() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_page_result}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         entries when is_list(entries) <- Map.get(attrs, :entries),
         next_cursor <- Map.get(attrs, :next_cursor),
         true <- Support.optional_binary?(next_cursor),
         total_count <- Map.get(attrs, :total_count),
         true <- Support.optional_non_neg_integer?(total_count),
         has_more <- Map.get(attrs, :has_more),
         true <- Support.optional_boolean?(has_more),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         entries: entries,
         next_cursor: next_cursor,
         total_count: total_count,
         has_more: has_more,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_page_result}
    end
  end
end
