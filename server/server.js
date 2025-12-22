import { createServer } from 'node:http';

const server = createServer((req, res) => {
	  res.writeHead(200, { 'Content-Type': 'text/plain' });
	  res.end('Hello World!\n');
});

// starts a simple http server locally on port 3000
server.listen(3000, '127.0.0.1', () => {
   console.log('Listening on 127.0.0.1:3000');
});
//

// 1. Auth Endpoints( Login/ logout) just basic
// 2. Distance and ETA Endpoints
// 		Given a room number/name and current position ->i can get the distance, shortest path and ETA of the room. 
// 3.	Room Info(CRUD)-> available rooms, and photo if exists
// 4. Prof Info( CRUD)-> available professors and photos if exists
// 5.	History( Given a username i can get the rooms or professor ever searched by the user and time) paginated response for this (5,10,15,20)