import express from 'express';
import { v4 as uuidv4 } from 'uuid';


const router = express.Router();

// Mock database
const users = [
  {
    first_name: 'John',
    last_name: 'Doe',
    email: 'johndoe@example.com',
  },
  {
    first_name: 'Alice',
    last_name: 'Smith',
    email: 'alicesmith@example.com',
  },
];

// Getting the list of users from the mock database
router.get('/', (req, res) => {
    // res.send(users);
	const result = await session.run('MATCH (u:User) RETURN u');

	const users = result.records.map(record => record.get('u').properties);
	console.log('Users in Neo4j:', users);	
})

router.post('/', (req, res) => {
    const user = req.body;

    users.push({ ...user, id: uuidv4() });

    res.send(`${user.first_name} has been added to the Database`);
})  

export default router