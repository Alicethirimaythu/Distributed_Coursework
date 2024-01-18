defmodule Server do
    def start(name, participants) do
        pid = spawn(Server, :init, [name, participants])
        Utils.register_name(name, pid, true)
    end

    def init(name, participants) do
        paxos = Paxos.start(name, participants)

        state = %{
            name: name,
            participants: participants,
            seating_plan: %{
                :A1=> nil, :A2=> nil, :A3=> nil,
                :B1=> nil, :B2=> nil, :B3=> nil,
                :C1=> nil, :C2=> nil, :C3=> nil
            },
            inst: 0,
            pax_pid: paxos
        }
        run(state)
    end

    def run(state) do
        state = receive do
            {:get_seating_plan, pid} ->
            # will send the seating plan from the state
            send(pid, {:seating_plan_sent, state.seating_plan})
            state

            ###----------------------###
            {:booking_seat, pid, seat_num, client_name} ->
                IO.puts("State - #{inspect(state)} \n\n\n")
                state = if Map.has_key?(state.seating_plan, String.to_atom(seat_num)) do
                    state = %{state | inst: state.inst+1}
                    inst_decision_made = Paxos.get_decision(state.pax_pid, state.inst, 5000)

                    state = if inst_decision_made == nil do
                        state = %{state | seating_plan: Map.replace(state.seating_plan, String.to_atom(seat_num), client_name)}
                        decision = Paxos.propose(state.pax_pid, state.inst, state.seating_plan, 5000)
                        IO.puts("This is the decision - #{inspect(decision)}")
                        IO.puts("This is the name in the seating_plan - #{Map.get(decision, String.to_atom(seat_num))}, current client name - #{client_name}")
                        if Map.get(decision, String.to_atom(seat_num)) == client_name do
                            send(pid, {:server_response, seat_num, true})
                        else
                            send(pid, {:server_response, seat_num, false})
                        end
                        state
                    else
                        state = %{state | seating_plan: inst_decision_made}
                        send(pid, {:error})
                        state
                    end
                state
                else
                    send(pid, {:server_response, nil, false})
                    state
                end
                state
        end
        run(state)
    end

end

####################### Client #######################

defmodule Client do
    def spinup(number_of_participants) do
        procs = Enum.to_list(0..number_of_participants) |> Enum.map(fn n -> :"p#{n}" end)
        Enum.map(procs, fn proc -> Server.start(proc, procs) end)
    end

    def kill (pids) do
        pids |> Enum.map(fn m -> Process.exit(m, :kill) end)
    end

    def view_seating_plan(server_pid) do
        IO.puts("#{inspect(self())}")
        send(server_pid, {:get_seating_plan, self()})
        receive do
            {:seating_plan_sent, seating_plan} ->
                IO.puts("#{inspect(seating_plan)}")
        end
    end

    def book_seat(name, seat_num, server_pid) do
        send(server_pid, {:booking_seat, self(), seat_num, name})
        receive do
            {:server_response, value, successful} ->
                if value != nil do
                    if successful == true do
                        IO.puts("#{IO.ANSI.green()}Booking successful for seat - #{value}! #{IO.ANSI.reset()}")
                    else
                        IO.puts("#{IO.ANSI.red()}Seat - #{value} is already booked! Please choose another seat.#{IO.ANSI.reset()}")
                    end
                else
                    IO.puts("#{IO.ANSI.red()}Invalid seat number! Please re-enter the seat number.#{IO.ANSI.reset()}")
                end

            {:error} ->
                IO.puts("#{IO.ANSI.yellow()}Error! Please re-enter the seat number.#{IO.ANSI.reset()}")
        end

    end
end
