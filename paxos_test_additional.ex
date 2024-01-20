defmodule PaxosTestAditional do

  # Leader crashes, no concurrent ballots
  def run_leader_crash_simple_before_decision(name, participants, val) do
    {cpid, pid} = PaxosTest.init(name, participants, true)
    send(cpid, :ready)

    {status, val, a, spare} =
      try do
        receive do
          :start ->
            IO.puts("#{inspect(name)}: started")

            [leader | spare] = Enum.sort(participants)
            [new_leader | _] = spare

            if name == leader do
              # Propose  when passed with :kill_before_decision will die right before a decision is selected
              Paxos.propose(pid, 1, val, 1000, :kill_before_decision)
            end

            if name == new_leader do
              Process.sleep(10)
              PaxosTest.propose_until_commit(pid, 1, val)
            end

            if name in spare do
              {status, val} = PaxosTest.wait_for_decision(pid, 1, 10000)

              if status != :none,
                do: IO.puts("#{name}: decided #{inspect(val)}"),
                else: IO.puts("#{name}: No decision after 10 seconds")

              {status, val, 10, spare}
            else
              {:killed, :none, -1, spare}
            end
        end
      rescue
        _ -> {:none, :none, 10, []}
      end

    send(cpid, :done)

    receive do
      :all_done ->
        Process.sleep(100)

        ql =
          if name in spare do
            IO.puts("#{name}: #{inspect(ql = Process.info(pid, :message_queue_len))}")
            ql
          else
            {:message_queue_len, -1}
          end

        PaxosTest.kill_paxos(pid, name)
        send(cpid, {:finished, name, pid, status, val, a, ql})
    end
  end

  # Leader crashes, no concurrent ballots
  def run_non_leader_send_propose_after_leader_elected(name, participants, val) do
    {cpid, pid} = PaxosTest.init(name, participants, true)
    send(cpid, :ready)

    {status, val, a, spare} =
      try do
        receive do
          :start ->
            IO.puts("#{inspect(name)}: started")

            [leader | spare] = Enum.sort(participants)
            [new_leader | _] = spare

            if name == new_leader do
              # Wait a bit for the leader to be elected
              Process.sleep(5000)
              Paxos.propose(pid, 1, val, 10000)
            end

            if name in spare do
              {status, val} = PaxosTest.wait_for_decision(pid, 1, 15000)

              if status != :none,
                do: IO.puts("#{name}: decided #{inspect(val)}"),
                else: IO.puts("#{name}: No decision after 10 seconds")

              {status, val, 10, spare}
            else
              {:killed, :none, -1, spare}
            end
        end
      rescue
        _ -> {:none, :none, 10, []}
      end

    send(cpid, :done)

    receive do
      :all_done ->
        Process.sleep(100)

        ql =
          if name in spare do
            IO.puts("#{name}: #{inspect(ql = Process.info(pid, :message_queue_len))}")
            ql
          else
            {:message_queue_len, -1}
          end

        PaxosTest.kill_paxos(pid, name)
        send(cpid, {:finished, name, pid, status, val, a, ql})
    end
  end

  def run_leader_should_nack_simple(name, participants, val) do
    {cpid, pid} = PaxosTest.init(name, participants, true)
    send(cpid, :ready)

    {status, val, a, spare} =
      try do
        receive do
          :start ->
            IO.puts("#{inspect(name)}: started")

            [leader | spare] = Enum.sort(participants)
            increase_ballot = Enum.take(spare, floor(length(participants) / 2))

            if name == leader do
              # Propose  when passed with :kill_before_decision will die right before a decision is selected
              Process.sleep(2000)
              res = Paxos.propose(pid, 1, val, 10000)

              if res != {:abort} do
                IO.puts("#{name}: Leader failed to abort")
                {:failed_to_abort, :none, 10, []}
              else
                Paxos.propose(pid, 1, val, 10000)

                {status, val} = PaxosTest.wait_for_decision(pid, 1, 10000)

                if status != :none,
                  do: IO.puts("#{name}: decided #{inspect(val)}"),
                  else: IO.puts("#{name}: No decision after 10 seconds")

                {status, val, 10, participants}
              end
            else
              if name in increase_ballot do
                Process.sleep(10)
                # Force the non leader process to have a higher ballot
                Paxos.propose(pid, 1, nil, 1000, :increase_ballot_number)
              end

              {status, val} = PaxosTest.wait_for_decision(pid, 1, 10000)

              if status != :none,
                do: IO.puts("#{name}: decided #{inspect(val)}"),
                else: IO.puts("#{name}: No decision after 10 seconds")

              {status, val, 10, participants}
            end

        end
      rescue
        _ -> {:none, :none, 10, []}
      end

    send(cpid, :done)

    receive do
      :all_done ->
        Process.sleep(100)

        ql =
          if name in spare do
            IO.puts("#{name}: #{inspect(ql = Process.info(pid, :message_queue_len))}")
            ql
          else
            {:message_queue_len, -1}
          end

        PaxosTest.kill_paxos(pid, name)
        send(cpid, {:finished, name, pid, status, val, a, ql})
    end
  end

  def run_non_leader_should_nack_simple(name, participants, val) do
    {cpid, pid} = PaxosTest.init(name, participants, true)
    send(cpid, :ready)

    {status, val, a, spare} =
      try do
        receive do
          :start ->
            IO.puts("#{inspect(name)}: started")

            participants = Enum.sort(participants)

            [leader | spare ] = participants
            increase_ballot = Enum.take(spare, floor(length(participants) / 2))
            [non_leader | _] = Enum.reverse(spare)

            if name == non_leader do
              # Propose  when passed with :kill_before_decision will die right before a decision is selected
              Process.sleep(2000)
              res = Paxos.propose(pid, 1, val, 10000)

              if res != {:abort} do
                IO.puts("#{name}: non-leader failed to abort")
                {:failed_to_abort, :none, 10, []}
              else
                Paxos.propose(pid, 1, val, 10000)

                {status, val} = PaxosTest.wait_for_decision(pid, 1, 10000)

                if status != :none,
                  do: IO.puts("#{name}: decided #{inspect(val)}"),
                  else: IO.puts("#{name}: No decision after 10 seconds")

                {status, val, 10, participants}
              end
            else
              if name in increase_ballot do
                Process.sleep(10)
                # Force the non leader process to have a higher ballot
                Paxos.propose(pid, 1, nil, 1000, :increase_ballot_number)
              end

              {status, val} = PaxosTest.wait_for_decision(pid, 1, 10000)

              if status != :none,
                do: IO.puts("#{name}: decided #{inspect(val)}"),
                else: IO.puts("#{name}: No decision after 10 seconds")

              {status, val, 10, participants}
            end

        end
      rescue
        _ -> {:none, :none, 10, []}
      end

    send(cpid, :done)

    receive do
      :all_done ->
        Process.sleep(100)

        ql =
          if name in spare do
            IO.puts("#{name}: #{inspect(ql = Process.info(pid, :message_queue_len))}")
            ql
          else
            {:message_queue_len, -1}
          end

        PaxosTest.kill_paxos(pid, name)
        send(cpid, {:finished, name, pid, status, val, a, ql})
    end
  end

end

