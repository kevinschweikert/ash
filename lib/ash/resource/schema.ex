defmodule Ash.Schema do
  @moduledoc false

  # Defines an ecto schema for a resource.

  # This defines struct representation of a resource. Data layers can rely on this
  # schema for persistence.

  defmacro define_schema do
    if Ash.Resource.Info.embedded?(__CALLER__.module) do
      quote unquote: false do
        alias Ash.Query.Aggregate
        use Ecto.Schema
        @primary_key false

        embedded_schema do
          for attribute <- Ash.Resource.Info.attributes(__MODULE__),
              attribute.name not in Ash.Resource.reserved_names() do
            read_after_writes? = attribute.generated? and is_nil(attribute.default)

            constraint_opts =
              case attribute.type do
                {:array, _type} ->
                  attribute.constraints[:items] || []

                _ ->
                  attribute.constraints
              end

            field(
              attribute.name,
              Ash.Type.ecto_type(attribute.type),
              Keyword.merge(
                constraint_opts,
                primary_key: attribute.primary_key?,
                read_after_writes: read_after_writes?,
                redact: attribute.sensitive?,
                source: attribute.source
              )
            )
          end

          field(:aggregates, :map, virtual: true, default: %{})
          field(:calculations, :map, virtual: true, default: %{})
          field(:__metadata__, :map, virtual: true, default: %{}, redact: true)
          field(:__order__, :integer, virtual: true)

          struct_fields_name =
            if Module.get_attribute(__MODULE__, :struct_fields) do
              :struct_fields
            else
              :ecto_struct_fields
            end

          Module.register_attribute(__MODULE__, :ash_struct_fields, accumulate: true)

          for field <- Module.get_attribute(__MODULE__, struct_fields_name) do
            Module.put_attribute(__MODULE__, :ash_struct_fields, field)
          end

          for relationship <- Ash.Resource.Info.relationships(__MODULE__),
              relationship.name not in Ash.Resource.reserved_names() do
            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {relationship.name, %Ash.NotLoaded{type: :relationship, field: relationship.name}}
            )
          end

          for aggregate <- Ash.Resource.Info.aggregates(__MODULE__),
              aggregate.name not in Ash.Resource.reserved_names() do
            if aggregate.kind == :custom do
              {:ok, aggregate.type}
            else
              Aggregate.kind_to_type(aggregate.kind, :string)
            end

            field(aggregate.name, Ash.Type.ecto_type(type), virtual: true)

            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {aggregate.name, %Ash.NotLoaded{type: :aggregate, field: aggregate.name}}
            )
          end

          for calculation <- Ash.Resource.Info.calculations(__MODULE__),
              calculation.name not in Ash.Resource.reserved_names() do
            {mod, _} = calculation.calculation

            field(calculation.name, Ash.Type.ecto_type(calculation.type), virtual: true)

            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {calculation.name, %Ash.NotLoaded{type: :calculation, field: calculation.name}}
            )
          end

          struct_fields = Module.get_attribute(__MODULE__, :ash_struct_fields)
          Module.delete_attribute(__MODULE__, struct_fields_name)
          Module.register_attribute(__MODULE__, struct_fields_name, accumulate: true)
          Enum.each(struct_fields, &Module.put_attribute(__MODULE__, struct_fields_name, &1))
        end
      end
    else
      quote unquote: false do
        alias Ash.Query.Aggregate
        use Ecto.Schema
        @primary_key false
        after_compile = @after_compile -- [{__MODULE__, :__after_compile__}]
        Module.delete_attribute(__MODULE__, :after_compile)
        Module.register_attribute(__MODULE__, :after_compile, accumulate: true)

        for compile_hook <- after_compile do
          @after_compile compile_hook
        end

        schema Ash.DataLayer.source(__MODULE__) do
          for attribute <- Ash.Resource.Info.attributes(__MODULE__),
              attribute.name not in Ash.Resource.reserved_names() do
            read_after_writes? = attribute.generated? and is_nil(attribute.default)

            constraint_opts =
              case attribute.type do
                {:array, _type} ->
                  attribute.constraints[:items] || []

                _ ->
                  attribute.constraints
              end

            field(
              attribute.name,
              Ash.Type.ecto_type(attribute.type),
              Keyword.merge(
                constraint_opts,
                primary_key: attribute.primary_key?,
                read_after_writes: read_after_writes?,
                redact: attribute.sensitive?,
                source: attribute.source
              )
            )
          end

          field(:aggregates, :map, virtual: true, default: %{})
          field(:calculations, :map, virtual: true, default: %{})
          field(:__metadata__, :map, virtual: true, default: %{}, redact: true)
          field(:__order__, :integer, virtual: true)

          struct_fields_name =
            if Module.get_attribute(__MODULE__, :struct_fields) do
              :struct_fields
            else
              :ecto_struct_fields
            end

          Module.register_attribute(__MODULE__, :ash_struct_fields, accumulate: true)

          for field <- Module.get_attribute(__MODULE__, struct_fields_name) do
            Module.put_attribute(__MODULE__, :ash_struct_fields, field)
          end

          for relationship <- Ash.Resource.Info.relationships(__MODULE__),
              relationship.name not in Ash.Resource.reserved_names() do
            case relationship do
              %{no_attributes?: true} ->
                :ok

              %{manual?: true} ->
                :ok

              %{manual: manual} when not is_nil(manual) ->
                :ok

              %{type: :belongs_to} ->
                belongs_to relationship.name, relationship.destination,
                  define_field: false,
                  references: relationship.destination_attribute,
                  foreign_key: relationship.source_attribute

              %{type: :has_many} ->
                has_many relationship.name, relationship.destination,
                  foreign_key: relationship.destination_attribute,
                  references: relationship.source_attribute

              %{type: :has_one} ->
                has_one relationship.name, relationship.destination,
                  foreign_key: relationship.destination_attribute,
                  references: relationship.source_attribute

              %{type: :many_to_many} ->
                many_to_many relationship.name, relationship.destination,
                  join_through: relationship.through,
                  join_keys: [
                    {relationship.source_attribute_on_join_resource,
                     relationship.source_attribute},
                    {relationship.destination_attribute_on_join_resource,
                     relationship.destination_attribute}
                  ]
            end

            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {relationship.name, %Ash.NotLoaded{type: :relationship, field: relationship.name}}
            )
          end

          for aggregate <- Ash.Resource.Info.aggregates(__MODULE__),
              aggregate.name not in Ash.Resource.reserved_names() do
            {:ok, type} =
              if aggregate.kind == :custom do
                {:ok, aggregate.type}
              else
                Aggregate.kind_to_type(aggregate.kind, :string)
              end

            field(aggregate.name, Ash.Type.ecto_type(type), virtual: true)

            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {aggregate.name, %Ash.NotLoaded{type: :aggregate, field: aggregate.name}}
            )
          end

          for calculation <- Ash.Resource.Info.calculations(__MODULE__),
              calculation.name not in Ash.Resource.reserved_names() do
            {mod, _} = calculation.calculation

            field(calculation.name, Ash.Type.ecto_type(calculation.type), virtual: true)

            Module.put_attribute(
              __MODULE__,
              :ash_struct_fields,
              {calculation.name, %Ash.NotLoaded{type: :calculation, field: calculation.name}}
            )
          end

          struct_fields = Module.get_attribute(__MODULE__, :ash_struct_fields)

          Module.delete_attribute(__MODULE__, struct_fields_name)
          Module.register_attribute(__MODULE__, struct_fields_name, accumulate: true)
          Enum.each(struct_fields, &Module.put_attribute(__MODULE__, struct_fields_name, &1))
        end
      end
    end
  end
end
