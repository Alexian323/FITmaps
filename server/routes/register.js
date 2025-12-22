import express from 'express';
import neo4j from 'neo4j-driver';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

router.post('/', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	

	const user = { ...req.body, id: uuidv4() };	
	const keys = Object.keys(user);
	const props = keys.map(key => `${key}: $${key}`).join(', ');
	const query = `CREATE (:User {${props}})`;
 
	const session = driver.session();
	// Add new user
	try {
		// Create a new user node
		 await session.run(query, user);
	} catch (error) {
		console.error(error);
		res.status(500).send('Error creating a user from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
	res.send(`${user.first_name} has been added to the Database`);
})  

export default router