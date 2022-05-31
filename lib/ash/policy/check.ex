defmodule Ash.Policy.Check do
  @moduledoc """
  A behaviour for declaring checks, which can be used to easily construct
  authorization rules.

  If a check can be expressed simply as a function of the actor, or the context of the request,
  see `Ash.Policy.SimpleCheck` for an easy way to write that check.
  If a check can be expressed simply with a filter statement, see `Ash.Policy.FilterCheck`
  for an easy way to write that check.
  """

  @type options :: Keyword.t()
  @type authorizer :: Ash.Policy.Authorizer.t()
  @type check_type :: :simple | :filter | :manual

  defstruct [:check, :check_module, :check_opts, :type]

  @doc false
  def transform(%{check: {check_module, opts}} = policy) do
    {:ok, %{policy | check_module: check_module, check_opts: opts}}
  end

  @type t :: %__MODULE__{}

  @doc """
  Strict checks should be cheap, and should never result in external calls (like database or api)

  It should return `{:ok, true}` if it can tell that the request is authorized, and `{:ok, false}` if
  it can tell that it is not. If unsure, it should return `{:ok, :unknown}`
  """
  @callback strict_check(struct(), authorizer(), options) :: {:ok, boolean | :unknown}
  @doc """
  An optional callback, that allows the check to work with policies set to `access_type :filter`

  Return a keyword list filter that will be applied to the query being made, and will scope the results to match the rule
  """
  @callback auto_filter(struct(), authorizer(), options()) :: Keyword.t()
  @doc """
  An optional callback, hat allows the check to work with policies set to `access_type :runtime`

  Takes a list of records, and returns `{:ok, true}` if they are all authorized, or `{:ok, list}` containing the list
  of records that are authorized. You can also just return the whole list, `{:ok, true}` is just a shortcut.

  Can also return `{:error, error}` if something goes wrong
  """
  @callback check(struct(), list(Ash.Resource.record()), map, options) ::
              {:ok, list(Ash.Resource.record()) | boolean} | {:error, Ash.Error.t()}
  @doc "Describe the check in human readable format, given the options"
  @callback describe(options()) :: String.t()

  @doc """
  The type of the check

  `:manual` checks must be written by hand as standard check modules
  `:filter` checks can use `Ash.Policy.FilterCheck` for simplicity
  `:simple` checks can use `Ash.Policy.SimpleCheck` for simplicity
  """
  @callback type() :: check_type()
  @optional_callbacks check: 4, auto_filter: 3

  def defines_check?(module) do
    :erlang.function_exported(module, :check, 4)
  end

  def defines_auto_filter?(module) do
    :erlang.function_exported(module, :auto_filter, 3)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Ash.Policy.Check

      def type, do: :manual
    end
  end
end