# def test(paxos_pid) do
#  propose = Paxos.propose(paxos_pid, :inst_1, :value_1, 1000)

#  handle(propose)
# end

# def handle({:abort}) do
#   1
# end

# def handle({:timeout}) do
#   2
# end

# def handle({:decision, v}) do
#  3
# end


defmodule Paxos do

  def start(name, participants) do
    pid = spawn(Paxos, :init, [name, participants])
    Utils.register_name(name, pid, false)
    pid
  end

  def init(name, participants) do
    ld = LeaderElection.start(name, participants)

    state = %{
      name: name,
      participants: participants,
      leader: nil,
      ####
      decided: false,
      inst_state: %{},
      inst_decisions: %{}
    }
    
    run(state)
  end

  def run(state) do

    state = receive do
      {:leader_elect, first_element} ->
        # leader election will send the leader to the paxos
        # it will be stored in the state.leader
        state = %{state | leader: first_element}
        IO.puts("#{state.name} trust the new leader #{first_element}!")
        # if state.name == state.leader and state.val != nil do
        #   IO.puts("#{state.leader} started a ballot!")
        #   Utils.beb_broadcast(state.participants, {:prepare, (state.bal + 1), state.name})
        # end
        if state.name == state.leader do
          for {key, val} <- state.inst_state, into: %{} do
           Utils.beb_broadcast(state.participants, {:prepare, key, state.inst_state[key].bal + 1, state.name})
          end
        end
        state
        

      ###--------------------###
      {:broadcast, inst, v, parent_name} ->
        # this is where the application propose value and send to paxos
        # if the process is elected as a leader, broadcast the prepare stage
        # if not, do nothing
        if state.inst_decisions[inst] != nil do
          send(parent_name, {:decision_made, state.inst_decisions[inst]})
          state
        else
          # state = %{state | val: v, inst: inst, parent_name: parent_name}
          state = %{state | inst_state: Map.put(state.inst_state, inst, %{
                parent_name: parent_name,
                bal: 0,
                a_bal: 0,
                a_val: nil,
                val: v,
                a_val_list: [], # a list that will track all the a_val with b_val in {a_val, a_bal} tuple from all the processes 
                ####
                prepared_quorum: 0,
                accepted_quorum: 0
          })}
          for {key, val} <- state.inst_state, into: %{} do
            Utils.beb_broadcast(state.participants, {:share_proposal, state.inst_state[key].val , key})
          end
          IO.puts("#{state.name} purposed a value to the leader!")
          state
        end

      ###--------------------###
      {:share_proposal, v, inst} ->
        # share the proposal to all the processes
        # IO.puts("#{state.name} got the share value!")
        ##### state = %{state | val: v, inst: inst}
        state = %{state | inst_state: Map.put(state.inst_state, inst, %{
              parent_name: nil,
              bal: 0,
              a_bal: 0,
              a_val: nil,
              val: v,
              a_val_list: [], # a list that will track all the a_val with b_val in {a_val, a_bal} tuple from all the processes 
              ####
              prepared_quorum: 0,
              accepted_quorum: 0
        })}
        IO.puts("#{state.name} got the value #{inspect(state.val)} !")
        state
        

      ###--------------------###
      {:prepare, inst, b, sender} ->
        # after leader started prepare ballot, all of the process will send prepared to the leader
        if b > state.bal do
          state = %{state | bal: b}
          IO.puts("#{state.name} prepared ballot #{state.bal}")
          Utils.unicast(sender, {:prepared, b, state.a_bal, state.a_val})
          state
        else
          IO.puts("#{state.name} send NACK from prepare!")
          Utils.unicast(sender, {:nack, b})
          state
        end

      ###--------------------###
      {:prepared, inst, b, a_bal, a_val} ->
        # whenever leader gets a prepared message, the quorum will increment
        # this is to track if the majority of process send prepared message to the leader
        state = %{state | prepared_quorum: state.prepared_quorum + 1}
        state = %{state | a_val_list: state.a_val_list++[{a_bal, a_val}]}
        IO.puts("Prepared Quorum - #{state.prepared_quorum}")
        state = if state.name == state.leader do
          # IO.puts("Prepared Quorum - #{state.name} is the leader")
          if state.prepared_quorum >= trunc(length(state.participants)/2 + 1) do
          IO.puts("#{state.name} Meet the prepare quorum!")

            state = if Enum.all?(state.a_val_list, fn {k,v} -> v == nil end) do
              IO.puts("#{state.name} - [a_val == nil] Setting val <- #{inspect(state.val)} ")
              state = %{state | val: state.val, prepared_quorum: 0}
              state
            else
              {a_bal, a_val} = Enum.reduce(state.a_val_list, {0, nil}, fn {k,v}, acc -> 
                {acc_k, acc_v} = acc
                if k > acc_k do
                  {k,v}
                else
                  {acc_k, acc_v}
                end
              end)
              IO.puts("#{state.name} - [a_val != nil] Setting val <- #{inspect(a_val)} ")
              state = %{state | val: a_val, prepared_quorum: 0}
              state
            end
          IO.puts("#{state.name} - has sent to participants to accept")
          Utils.beb_broadcast(state.participants, {:accept, b, state.val, state.name})
          state
          else
            state
          end
        else
          state  
        end
        state

      ###--------------------###
      {:accept, inst, b, v, sender} ->
        if b >= state.bal do
          IO.puts("#{state.name} send accepted the value #{inspect(state.val)}")
          state = %{state | bal: b, a_bal: b, a_val: v}
          Utils.unicast(sender, {:accepted, b})
          state
        else
          IO.puts("#{state.name} send NACK from accepted!")
          Utils.unicast(sender, {:nack, b})
          state
        end

      ###--------------------###
      {:accepted, inst, b} ->
        state = %{state | accepted_quorum: state.accepted_quorum + 1}
        IO.puts("#{state.name} Quorum - #{state.accepted_quorum}")
        if state.name == state.leader do
          if state.accepted_quorum >= trunc(length(state.participants)/2 + 1) do
            IO.puts("#{state.name} Meet the accepted quorum!")
            state = %{state | decided: true}
            Utils.beb_broadcast(state.participants, {:instance_decision, state.val}) # send it to everyone to store it in instance_proposal
            state = %{state | accepted_quorum: 0}
            state
          else
            state
          end
        else
          state
        end

      ###--------------------###
      {:nack, inst, b} ->
        if state.name == state.leader do
          Utils.unicast(state.parent_name, {:nack, b})
        end
        state
      
      ###--------------------###
      {:instance_decision, decision} ->
        state = %{state | inst_decisions: Map.put(state.inst_decisions, state.inst, decision)}
        IO.puts("#{state.name} - instance decisions values: #{inspect(state.inst_decisions)}")
        if state.parent_name != nil do
          send(state.parent_name, {:decision_made, state.val})
        end
        state

      ###--------------------###
      {:get_decision, inst, parent_name} ->
        if Map.get(state.inst_decisions, inst) != nil do
          send(parent_name, {:decision_response, Map.get(state.inst_decisions, inst)})
        else
          send(parent_name, {:decision_response, nil})
        end
        state

    end
    run(state)
  end

  def get_decision(pid, inst, t) do
    Process.send_after(pid, {:get_decision, inst, self()}, t)
    decision = receive do
      {:decision_response, value} ->
        # IO.puts("returning value in :decision_responce #{inspect(value)}")
        value
    after
      t -> nil
    end
    
  end

  def propose(pid, inst, value, t) do
    # do paxos stuff

    # this will be called in the beginning of the step one as every process will propose a value
    # then the leader will start its ballot
    send(pid, {:broadcast, inst, value, self()})
    result = receive do
      {:decision_made, value} ->
        IO.puts("returning value in :propose_responce #{inspect(value)}")
        {:decision, value}
    after
      t -> {:timeout}
    end
  end

end