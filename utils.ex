defmodule Utils do
  def unicast(p, m) do
    case :global.whereis_name(p) do
            pid when is_pid(pid) -> send(pid, m)
            :undefined -> :ok
    end
  end

  # Best-effort broadcast of m to the set of destinations dest
  def beb_broadcast(dest, m), do: for p <- dest, do: unicast(p, m)

  def add_to_name(name, to_add), do: String.to_atom(Atom.to_string(name) <> to_add)

  def register_name(name, pid, link \\ true) do # \\ is default value
    case :global.re_register_name(name, pid) do
      :yes ->
        # Note this is running on the parent so we are linking the parent to the rb
        # so that when we close the parent the rb also dies
        if link do
          Process.link(pid)
        end

        pid

      :no ->
        Process.exit(pid, :kill)
        :error
    end
  end
end