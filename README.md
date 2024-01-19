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


### **Assumptions**

I don't know what to write about



