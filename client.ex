defmodule Client do
    def spinup(number_of_participants) do
        procs = Enum.to_list(0..number_of_participants) |> Enum.map(fn n -> :"p#{n}" end)
        Enum.map(procs, fn proc -> Server.start(proc, procs) end)
    end

    def kill (pids) do
        pids |> Enum.map(fn m -> Process.exit(m, :kill) end)
    end

    def view_seating_plan(server_pid) do
        send(server_pid, {:get_seating_plan, self()})
        receive do
            {:seating_plan_sent, seating_plan} ->
                IO.puts("#{seating_plan}")
        end
    end

    # def book_seat(name, seat_num) do
        
    # end
end