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
        :A1 => nil,
        :A2 => nil,
        :A3 => nil,
        :B1 => nil,
        :B2 => nil,
        :B3 => nil,
        :C1 => nil,
        :C2 => nil,
        :C3 => nil
      },
      inst: 0,
      pax_pid: paxos
    }

    run(state)
  end

  def run(state) do
    state =
      receive do
        {:get_seating_plan, pid} ->
          # updates till latest decision
          state = check_latest_seating(state)

          # will send the seating plan from the state
          send(pid, {:seating_plan_sent, state.seating_plan})
          state

        ### ----------------------###
        {:booking_seat, pid, seat_num, client_name} ->
          # updates till latest decision
          state = check_latest_seating(state)

          #   IO.puts("#{pid} - State: #{inspect(state)} \n")

          # if the seat_num exists in the seat_plan
          state =
            if Map.has_key?(state.seating_plan, String.to_atom(seat_num)) do
              # ? returning: Invalid seat number! Please re-enter the seat number.
              send(pid, {:server_response, nil, false})
              state
            end

          # need to check if the seat has already been booked

          if Map.get(state.seating_plan, String.to_atom(seat_num)) == nil do
            decision =
              Paxos.propose(
                state.pax_pid,
                state.inst,
                Map.replace(state.seating_plan, String.to_atom(seat_num), client_name),
                5000
              )

            state = %{state | seating_plan: decision, inst: state.inst + 1}
            # ? returning successful booking
            send(pid, {:server_response, seat_num, true})
            state

            # IO.puts("This is the name in the seating_plan - #{Map.get(decision, String.to_atom(seat_num))}")
          else
            # ? the seat has already been booked
            send(pid, {:server_response, seat_num, false})
            state
          end

          state
      end

    run(state)
  end

  def check_latest_seating(state) do
    decision = Paxos.get_decision(state.pax_pid, state.inst, 1000)

    if decision != nil do
      IO.puts("#{state.name} - has updated get_decision")
      state = %{state | inst: state.inst + 1, seating_plan: decision}
      state
      check_latest_seating(state)
    else
      state
    end
  end
end

####################### Client #######################

defmodule Client do
  def spinup(number_of_participants) do
    procs = Enum.to_list(0..number_of_participants) |> Enum.map(fn n -> :"p#{n}" end)
    Enum.map(procs, fn proc -> Server.start(proc, procs) end)
  end

  def kill(pids) do
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
            IO.puts(
              "#{IO.ANSI.green()}Booking successful for seat - #{value}! #{IO.ANSI.reset()}"
            )
          else
            IO.puts(
              "#{IO.ANSI.red()}Seat - #{value} is already booked! Please choose another seat.#{IO.ANSI.reset()}"
            )
          end
        else
          IO.puts(
            "#{IO.ANSI.red()}Invalid seat number! Please re-enter the seat number.#{IO.ANSI.reset()}"
          )
        end

      {:error} ->
        IO.puts("#{IO.ANSI.yellow()}Error! Please re-enter the seat number.#{IO.ANSI.reset()}")
    end
  end
end
