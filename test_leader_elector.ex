defmodule TestLeaderElector do

  def run() do
    IO.puts("Testing Leader Elector")

    procs = Enum.map(1..20, fn i -> String.to_atom("p#{i}") end)
    pids = Enum.map(procs, fn p -> start(p, procs) end)

    IO.puts("spawned")

    Process.send_after(self(), {:end}, 50000)

    receive do
      {:end} ->
        IO.puts("test ended")
    end
  end

  def start(name, procs) do
    pid = spawn(TestLeaderElector, :init, [name, procs])

    case :global.re_register_name(name, pid) do
      :yes ->
        # Note this is running on the parent so we are linking the parent to the rb
        # so that when we close the parent the rb also dies
        pid

      :no ->
        :error
    end
  end

  def init(name, procs) do
    IO.puts("#{name}: init")
    LeaderElection.start(name, procs)

    run_test(name)
  end

  def run_test(name) do
    receive do
      {:leader_elect, proc} ->
        IO.puts("#{name}: trust process #{Atom.to_string(proc)}")

        if proc == name do
          IO.puts("#{name}: Trust myself will stop\n\n\n")
          Process.exit(self(), :exit)
        end
    end

    run_test(name)
  end
end