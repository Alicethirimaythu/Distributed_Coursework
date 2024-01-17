defmodule LeaderElection do
    def start(name, participants) do
        #edit name to include leader_election -  means it won't get mixed up with other processes
        new_name = Utils.add_to_name(name, "leader_election")

        #in participants, change all the processes names to add on leader elections
        participants = Enum.map(participants, fn x -> Utils.add_to_name(x, "leader_election") end)

        pid = spawn(LeaderElection, :init, [new_name, participants, name])
        
        Utils.register_name(new_name, pid)

        pid
    end

    def init(name, participants, parent_name) do
        state = %{ 
            name: name, 
            participants: participants,
            leader: nil,
            parent_name: parent_name,
            alive: %MapSet{},
            timeout: 1000
        }
        Process.send_after(self(), {:timeout}, state.timeout)
        run(state)
    end

    def run(state) do
        state = receive do
            {:timeout} ->  
                #send a heart beat
                Utils.beb_broadcast(state.participants, {:heartbeat_request, self()})
                
                #start a timeout again after it timeout. so it is in the loop of checking if everything is alive
                Process.send_after(self(), {:timeout}, state.timeout)

                state = elect(state)
                #when the timeout happens, empty alive list.
                state = %{state | alive: %MapSet{}}
                
                state

            {:heartbeat_request, pid} ->
                #reply back the heartbeat
                send(pid, {:heartbeat_reply, state.parent_name})
                state

            {:heartbeat_reply, name} ->
                %{state | alive: MapSet.put(state.alive, name)}

        end
        run(state)
    end

    def elect(state) do
        sorted = Enum.sort(state.alive) # sort return a list
        if MapSet.size(state.alive) > 0 do
            first_element = Enum.at(sorted, 0) #get the first element to be elected as a leader
            # check soon to be elected leader is the leader that is still alive
            # if so do not need to be elected again
            # if not elect it to be a leader
            if first_element != state.leader do
                Utils.unicast(state.parent_name, {:leader_elect, first_element})
                %{state | leader: first_element}
            else
                state
            end
        else
            state
        end
    end


end