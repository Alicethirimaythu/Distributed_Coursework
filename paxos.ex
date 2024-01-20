defmodule Paxos do
  def start(name, participants) do
    # do spawn stuff

    # is a function that takes an atom name, and a list of
    # atoms participants as arguments. It spawns a Paxos process, registers it in the global
    # registry under the name name, and returns the identifier of the newly spawned process.
    # The argument participants must be assumed to include symbolic names of all
    # replicas (including the one specified by name) participating in the protocol.

    pid_pax = spawn(Paxos, :init, [name, participants])

    Utils.register_name(name, pid_pax, false)
  end

  def init(name, participants) do
    leader = Leader_election.start(name, participants)

    state = %{
      # name of the process
      name: name,
      # parent process application name
      parent_name: nil,
      # list of other processes in the network
      participants: participants,
      # leader process is updated in :leader_elect
      leader: nil,
      instance_state: %{},
      instance_decision: %{},
      action: nil
    }

    run(state)
  end

  def run(state) do
    # run stuff
    state =
      receive do
        {:leader_elect, first_elem} ->
          IO.puts("#{state.name} - Leader #{first_elem} is the new leader!")
          # called by leader_election.ex to tell parent process which process is leader
          state = %{state | leader: first_elem}

          if state.name == state.leader do
            Enum.reduce(Map.keys(state.instance_state), 0, fn x, acc ->
              Utils.beb_broadcast(
                state.participants,
                {:prepare, x, state.instance_state[x].bal + 1, state.leader}
              )
            end)
          end

          state

        {:broadcast, instance_num, value, parent_process, action} ->
          state =
            if action == :increase_ballot_number do
              IO.puts(
                "#{state.name} - Got request to increase ballot number for inst #{instance_num}"
              )

              state = check_instance_state_exist(state, instance_num)

              %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | bal: state.instance_state[instance_num].bal + 1
                    })
              }
            else
              state = %{state | parent_name: parent_process, action: action}
              Utils.beb_broadcast(state.participants, {:share_proposal, value, instance_num})
              state
            end

          IO.puts(
            "#{state.name} - with #{instance_num} has proposed #{inspect(value)} to the leader! "
          )

          state

        {:share_proposal, proposal, instance_num} ->
          state = check_instance_state_exist(state, instance_num)
          IO.puts("#{state.name} - has recieved a proposal of val: #{inspect(proposal)}")

          state =
            if state.instance_state[instance_num].v == nil do
              %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | v: proposal
                    })
              }
            else
              state
            end

          if state.name == state.leader do
            IO.puts(
              "#{state.name} - #{state.leader} has started a ballot! b-#{inspect(state.instance_state[instance_num].bal)}"
            )

            Utils.beb_broadcast(
              state.participants,
              {:prepare, instance_num, state.instance_state[instance_num].bal + 1, state.leader}
            )
          end

          state

        {:prepare, instance_num, b, leader} ->
          state = check_instance_state_exist(state, instance_num)

          if b > state.instance_state[instance_num].bal do
            IO.puts("#{state.name} - sending a prepared to leader! | leader: #{inspect(leader)}")

            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | bal: b
                  })
            }

            Utils.unicast(
              leader,
              {:prepared, instance_num, b, state.instance_state[instance_num].a_bal,
               state.instance_state[instance_num].a_val}
            )

            state
          else
            IO.puts(
              "#{state.name} - NACK SENT | b:#{inspect(b)} | bal #{inspect(state.instance_state[instance_num].bal)}"
            )

            Utils.beb_broadcast(state.participants, {:nack, b})
            state
          end

        {:prepared, instance_num, b, a_bal, a_val} ->
          state = check_instance_state_exist(state, instance_num)

          if state.name == state.leader and b == state.instance_state[instance_num].bal do
            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | quorums_prepared: state.instance_state[instance_num].quorums_prepared + 1,
                      a_val_list:
                        state.instance_state[instance_num].a_val_list ++ [{a_bal, a_val}]
                  })
            }

            if state.instance_state[instance_num].quorums_prepared >=
                 floor(length(state.participants) / 2) + 1 do
              IO.puts(
                "#{state.name} - Quorums Prepared Met! #{inspect(state.instance_state[instance_num].quorums_prepared)}"
              )

              {_, a_val} =
                Enum.reduce(state.instance_state[instance_num].a_val_list, {0, nil}, fn {k, v},
                                                                                        acc ->
                  {acc_k, acc_v} = acc

                  if k > acc_k and k != nil do
                    {k, v}
                  else
                    {acc_k, acc_v}
                  end
                end)

              IO.puts("#{state.name} - prepared - #{inspect(a_val)}")

              a_val =
                if a_val == nil do
                  state.instance_state[instance_num].v
                else
                  a_val
                end

              state = %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | quorums_prepared: 0,
                        v: a_val
                    })
              }

              IO.puts("#{state.name} - has sent to participants to accept")

              Utils.beb_broadcast(
                state.participants,
                {:accept, instance_num, b, state.instance_state[instance_num].v, state.name}
              )

              state
            else
              state
            end
          else
            state
          end

        {:accept, instance_num, b, v, leader} ->
          state = check_instance_state_exist(state, instance_num)

          if b >= state.instance_state[instance_num].bal do
            IO.puts("#{state.name} - #{state.name} has accepted bal: #{b} | v: #{inspect(v)}")

            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | bal: b,
                      a_bal: b,
                      a_val: v
                  })
            }

            Utils.unicast(leader, {:accepted, instance_num, b})
            state
          else
            IO.puts("#{state.name} - NACK SENT")
            Utils.beb_broadcast(state.participants, {:nack, b})
            state
          end

        {:accepted, instance_num, b} ->
          state = check_instance_state_exist(state, instance_num)

          if state.name == state.leader do
            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | quorums_accepted: state.instance_state[instance_num].quorums_accepted + 1
                  })
            }

            if state.instance_state[instance_num].quorums_accepted >=
                 floor(length(state.participants) / 2) + 1 do
              IO.puts(
                "#{state.name} - Quorums Accepted Met! cnt: #{state.instance_state[instance_num].quorums_accepted}"
              )

              IO.puts("#{state.name} is sending decision ")

              if state.action == :kill_before_decision do
                IO.puts(
                  "#{state.name} - Leader has action to die before decision #{inspect({:decide, instance_num, state.instance_state[instance_num].v})}"
                )

                Process.exit(self(), :kill)
              end

              Utils.beb_broadcast(
                state.participants,
                {:instance_decision, instance_num, state.instance_state[instance_num].v}
              )

              state = %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | quorums_accepted: 0
                    })
              }

              state
            else
              state
            end
          else
            state
          end

        {:instance_decision, instance_num, decision} ->
          state = check_instance_state_exist(state, instance_num)

          state = %{
            state
            | instance_decision: Map.put(state.instance_decision, instance_num, decision)
          }

          IO.puts(
            "#{state.name} - Updated Map #{inspect(state.instance_decision)} | Parent: #{inspect(state.parent_name)}"
          )

          if state.parent_name != nil do
            send(state.parent_name, {:propose_responce, state.instance_state[instance_num].v})
          end

          state

        {:get_decision, instance_num, parent_process} ->
          IO.puts("#{state.name} - trying to print a decision num #{instance_num}")

          if state.instance_decision[instance_num] != nil do
            send(
              parent_process,
              {:decision_responce, state.instance_decision[instance_num]}
            )
          end

          state

        # TODO missing instance nubmer
        {:nack, b} ->
          if state.parent_name != nil do
            send(state.parent_name, {:abort})
          end

          state
      end

    run(state)
  end

  def check_instance_state_exist(state, instance_num) do
    if state.instance_state[instance_num] == nil do
      IO.puts("#{state.name} - create new instance | #{inspect(instance_num)}")

      state = %{
        state
        | instance_state:
            Map.put(state.instance_state, instance_num, %{
              # the current ballot [a number]
              bal: 0,
              # accepted ballot
              a_bal: nil,
              # accepted ballot value
              a_val: nil,
              a_val_list: [],
              # proposal
              v: nil,
              quorums_prepared: 0,
              quorums_accepted: 0
            })
      }
    else
      state
    end
  end

  def get_decision(pid_pax, inst, t) do
    # takes the process identifier pid of a process running a Paxos replica, an instance identifier inst, and a timeout t in milliseconds

    # return v != nil if v is the value decided by consensus instance inst
    # return nil in all other cases

    send(pid_pax, {:get_decision, inst, self()})
    # send(pid_pax, {:get_decision, inst, t, self()})
    receive do
      {:decision_responce, v} ->
        IO.puts("returning v in :decision_responce #{inspect(v)}")
        v
    after
      t -> nil
    end
  end

  def propose(pid_pax, inst, value, t, action \\ nil) do
    # is a function that takes the process identifier
    # pid of an Elixir process running a Paxos replica, an instance identifier inst, a timeout t
    # in milliseconds, and proposes a value value for the instance of consensus associated
    # with inst. The values returned by this function must comply with the following
    send(pid_pax, {:broadcast, inst, value, self(), action})

    receive do
      {:propose_responce, v} ->
        IO.puts("returning v in :propose_responce #{inspect(v)}")
        v

      {:abort} ->
        {:abort}
    after
      t -> {:timeout}
    end
  end
end

defmodule Leader_election do
  # pick lowest process
  # processes wait to hear back
  # timeout  if nothing heard
  # when heard back pick leader
  # if wrong leader elected, Paxos will reject proposals, because not leader (if check)

  def start(name, participants) do
    pid = spawn(Leader_election, :init, [name, participants])

    Utils.register_name(Utils.add_to_name(name, "_LeaderElec"), pid)

    # case :global.re_register_name(Utils.add_to_name(name, "_LeaderElec"), pid) do
    #     :yes -> pid
    #     :no  -> :error
    # end
    # Process.link(pid)
    # IO.puts "registered #{name}"
    # pid
  end

  def init(name, participants) do
    state = %{
      name: Utils.add_to_name(name, "_LeaderElec"),
      # update to be paxos process name
      parent_name: name,
      participants: Enum.map(participants, fn n -> Utils.add_to_name(n, "_LeaderElec") end),
      alive: %MapSet{},
      leader: nil,
      timeout: 100
    }

    Process.send_after(self(), {:timeout}, 1000)

    run(state)
  end

  def run(state) do
    state =
      receive do
        {:timeout} ->
          # send heartbeat out to list of processes
          # Await using delay of timeout
          # sort the alive
          # Assign leader from list of replied processes
          # Clear the list

          # IO.puts("#{state.name}: #{inspect({:timeout})}")

          Utils.beb_broadcast(state.participants, {:heartbeat_req, self()})

          Process.send_after(self(), {:timeout}, state.timeout)

          state = elec_leader(state)

          %{state | alive: %MapSet{}}

        {:heartbeat_req, pid} ->
          # IO.puts("#{state.name}: #{inspect({:heartbeat_req, pid})}")
          send(pid, {:heartbeat_reply, state.parent_name})
          state

        {:heartbeat_reply, name} ->
          # IO.puts("#{state.name}: #{inspect {:heartbeat_reply, name}}")
          %{state | alive: MapSet.put(state.alive, name)}
      end

    run(state)
  end

  defp elec_leader(state) do
    # when more than 1 process is alive
    if MapSet.size(state.alive) > 0 do
      # sort the list and make the first element the leader
      first_elem = Enum.at(Enum.sort(state.alive), 0)
      # if first elem is already leader dont elect new leader
      if first_elem != state.leader do
        Utils.unicast(state.parent_name, {:leader_elect, first_elem})
        # the new leader is set
        %{state | leader: first_elem}
      else
        state
      end
    else
      state
    end
  end
end

defmodule EagerReliableBroadcast do
  def start(name, processes, upper) do
    pid = spawn(EagerReliableBroadcast, :init, [name, processes, upper])
    # :global.unregister_name(name)
    case :global.re_register_name(name, pid) do
      :yes -> pid
      :no -> :error
    end

    IO.puts("registered #{name}")
    pid
  end

  # Init event must be the first
  # one after the component is created
  def init(name, processes, upper_layer) do
    state = %{
      name: name,
      processes: processes,
      upper_layer: upper_layer,

      # Tracks the sets of message sequence numbers received from each process
      delivered: for(p <- processes, into: %{}, do: {p, %MapSet{}}),

      # Tracks the highest contiguous message sequence number received from each process
      all_up_to: for(p <- processes, into: %{}, do: {p, -1}),

      # Current sequence number to assign to a newly broadcast message
      seq_no: 0
    }

    run(state)
  end

  def run(state) do
    state =
      receive do
        {:broadcast, m} ->
          data_msg = {:data, state.name, state.seq_no, m}
          state = %{state | seq_no: state.seq_no + 1}
          beb_broadcast(data_msg, state.processes)

          # Replace beb_broadcast above with the one below to
          # simulate the scenario in which :p0 does not broadcast to :p0 and :p1, and
          # no one broadcasts to :p0.
          # beb_broadcast_with_failures(state.name, :p0, [:p0, :p1], data_msg, state.processes)

          # IO.puts("#{inspect state.name}: RB-broadcast: #{inspect m}")
          state

        {:data, proc, seq_no, m} ->
          # IO.puts("#{inspect state.name}: BEB-deliver: #{inspect m} from #{inspect proc}, seqno=#{inspect seq_no}")
          delivered = state.delivered[proc]
          all_up_to = state.all_up_to[proc]

          # IO.puts("#{inspect state.name}: delivered=#{inspect delivered}, all_up_to=#{inspect all_up_to}, seq_no=#{inspect seq_no}")

          # This is a new message
          if seq_no > all_up_to and seq_no not in delivered do
            # IO.puts("#{inspect state.name}: New message: #{inspect m} from #{inspect proc}, seqno=#{inspect seq_no}")
            # update delivered of proc with a new sequence number
            delivered = MapSet.put(delivered, seq_no)
            # Try to compact delivered and update all_up_to
            {delivered, all_up_to} = compact_delivered(delivered, all_up_to)
            # Trigger deliver indiciation
            send(state.upper_layer, {:rb_deliver, proc, m})
            # Rebroadcast the message to ensure Agreement
            beb_broadcast({:data, proc, seq_no, m}, state.processes)

            # Replace beb_broadcast above with the one below to
            # simulate the scenario in which :p0 does not broadcast to :p0 and :p1, and
            # no one broadcasts to :p0.
            # beb_broadcast_with_failures(state.name, :p0, [:p0, :p1], data_msg, state.processes)
            # beb_broadcast_with_failures(state.name, :p0, [:p0, :p1, :p2], {:data, proc, seq_no, m}, state.processes)

            # IO.puts("#{inspect state.name}: Echo: #{inspect m} from #{inspect proc}, seqno=#{inspect seq_no}")

            # Update the state to reflect updates to delivered and all_up_to
            %{
              state
              | delivered: %{state.delivered | proc => delivered},
                all_up_to: %{state.all_up_to | proc => all_up_to}
            }
          else
            # IO.puts("#{inspect state.name}: Delivered before: #{inspect m} from #{inspect proc}, seqno=#{inspect seq_no}")
            state
          end
      end

    run(state)
  end

  # Compute the next highest contiguous message sequence number in the set s
  # starting from seqno
  defp get_upper_seqno(seqno, s) do
    if seqno in s, do: get_upper_seqno(seqno + 1, s), else: seqno - 1
  end

  # Try to compact the delivered set for a process
  # as per the algorithm described in the handout
  defp compact_delivered(delivered, all_up_to) do
    new_upper_seqno = get_upper_seqno(all_up_to + 1, delivered)

    if new_upper_seqno > all_up_to do
      delivered =
        Enum.reduce((all_up_to + 1)..new_upper_seqno, delivered, fn sn, s ->
          MapSet.delete(s, sn)
        end)

      all_up_to = new_upper_seqno
      {delivered, all_up_to}
    else
      {delivered, all_up_to}
    end
  end

  # Send message m point-to-point to process p
  defp unicast(m, p) do
    case :global.whereis_name(p) do
      pid when is_pid(pid) -> send(pid, m)
      :undefined -> :ok
    end
  end

  # Best-effort broadcast of m to the set of destinations dest
  defp beb_broadcast(m, dest), do: for(p <- dest, do: unicast(m, p))

  # Simulate a scenario in which proc_to_fail fails to send the message m
  # to the processes in fail_send_to, and all other processes fail
  # to send to proc_to_fail
  defp beb_broadcast_with_failures(name, proc_to_fail, fail_send_to, m, dest) do
    if name == proc_to_fail do
      for p <- dest, p not in fail_send_to, do: unicast(m, p)
    else
      for p <- dest, p != proc_to_fail, do: unicast(m, p)
    end
  end
end

defmodule Utils do
  def unicast(p, m) when p == nil, do: IO.puts("!!! Sending to nil with val #{inspect(m)}")

  def unicast(p, m) do
    case :global.whereis_name(p) do
      pid when is_pid(pid) -> send(pid, m)
      :undefined -> :ok
    end
  end

  # Best-effort broadcast of m to the set of destinations dest
  def beb_broadcast(dest, m), do: for(p <- dest, do: unicast(p, m))

  def add_to_name(name, to_add), do: String.to_atom(Atom.to_string(name) <> to_add)

  # \\ means default
  def register_name(name, pid, link \\ true) do
    case :global.re_register_name(name, pid) do
      :yes ->
        # parent runs this to link to leader + ERB
        # when one dies all links also die

        # if link true
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
