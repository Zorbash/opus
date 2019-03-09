defmodule Opus.Pipeline.Registration do
  @moduledoc false

  def define_callback(_type, _stage_id, _name, nil) do
    quote do: :ok
  end

  def define_callback(type, stage_id, name, quoted_fun) do
    {name, _} = Code.eval_quoted(name)
    callback_name = :"opus_#{type}_callback_stage_#{name}_#{stage_id}"

    quote do
      if is_function(unquote(quoted_fun)) do
        if :erlang.fun_info(unquote(quoted_fun))[:arity] in [0, 1] do
          @opus_callbacks %{
            stage_id: unquote(stage_id),
            type: unquote(type),
            name: unquote(callback_name)
          }
        end

        case :erlang.fun_info(unquote(quoted_fun))[:arity] do
          0 ->
            @doc false
            def unquote(callback_name)() do
              unquote(quoted_fun).()
            end

          1 ->
            @doc false
            def unquote(callback_name)(input) do
              unquote(quoted_fun).(input)
            end

          n ->
            IO.warn(
              "Expected #{unquote(type)} of #{unquote(name)} to take either 0 or 1 parameters, got #{
                n
              }"
            )
        end
      end
    end
  end

  def maybe_define_callbacks(stage_id, name, opts) do
    [
      define_callback(:if, stage_id, name, Access.get(opts, :if)),
      define_callback(:unless, stage_id, name, Access.get(opts, :unless)),
      define_callback(:with, stage_id, name, Access.get(opts, :with)),
      define_callback(:retry_backoff, stage_id, name, Access.get(opts, :retry_backoff))
    ]
  end

  def normalize_opts(opts, id, callbacks) do
    callback_types = for %{stage_id: ^id, type: type} <- callbacks, do: type
    Keyword.merge(opts, for(t <- callback_types, do: {t, :anonymous}))
  end
end
