# COM3026 Group Courswork (Paxos)

 *Group members: Liam O'Driscoll(lo00301), Thiri May Thu @ Alice(tt00562)*

## **Cinema Seating Plan Application**

### **Interface**

* ***view_seating_plan(server_pid)***: get the floor plan of the seating plan from the server and print the seating plan as a map in the terminal (e.g., %{A1: nil, A2: nil, A3: "Tom", ...})
* ***book_seat(name, seat_num, server_pid)***: book a seat with a name will get a comment which is either:
    * "Booking successful for seat - #{seat_num}!" -  if it is successfully booked
    * "Seat - #{seat_num} is already booked! Please choose another seat." - if the seat is already reserved
    * "Invalid seat number! Please re-enter the seat number." - when the client enter the wrong seat number.

### **Safety and Livenss Properties**

- ***Safety***:
    - A seat that is already reserved cannot be booked
    - The seat number that are not in the seating plan cannot be booked
- ***Liveness***: 
    - Seat bookings are guaranteed to terminate assuming it is not executed concurrently


### **Usage Instructions**

- firstly, call Client.spinup(number_of_servers) to start the servers (ie., Client.spinup(3), this will spawn 3+1 servers).
- for the ***server_pid*** param, you need to choose one of the servers specifically. (ie., server_pid_A = Enum.at(pids, 0))
- To view the seating plan, call ***view_seating_plan(server_pid)*** to print out the map of the seating plan that is stored in the server.
- To book a seat, call ***book_seat(name, seat_num, server_pid)*** to book a seat. The functionality of this function is listed in the Interface.
- Client.kill(pids) will kill all the servers that are spawned


### **Assumptions**

- Any previous servers that had spun up will not be connected with the servers that have spun up after.
- The clients cannot book the seats concurrently (at the same time)

### **Extra Features**

- Whenever view_seating_plan and book_seat functions are called, the server called will be updated till the latest decision made in Paxos if needed to. 

