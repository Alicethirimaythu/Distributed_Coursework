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
                A1: nil, A2: nil, A3: nil,
                B1: nil, B2: nil, B3: nil,
                C1: nil, C2: nil, C3: nil
            }
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
            # {:book_seat }
        end
        run(state)
    end

end