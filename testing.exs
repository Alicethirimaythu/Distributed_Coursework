IEx.Helpers.c "paxos.ex", "."
IEx.Helpers.c "server.ex", "."


pids = Client.spinup(3)
server_pid_A = Enum.at(pids, 0)
server_pid_B = Enum.at(pids, 1)
Client.view_seating_plan(server_pid_A)
Client.book_seat("A", "A1", server_pid_A)
Client.book_seat("A", "A2", server_pid_A)
Client.book_seat("A", "A3", server_pid_A)
Client.book_seat("B", "A2", server_pid_A)
# Client.book_seat("C", "A2", server_pid_A)
Client.book_seat("TEST", "B3", server_pid_B)
# Client.book_seat("TEST", "A3", server_pid_B)
# Client.book_seat("TEST", "A3", server_pid_B)
IO.puts("\n")
Client.view_seating_plan(server_pid_A)
Client.view_seating_plan(server_pid_B)
