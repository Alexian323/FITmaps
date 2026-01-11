import express from 'express';
import neo4j from 'neo4j-driver';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

router.get('/', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	

	const session = driver.session();
	try {
		const result = await session.run('MATCH (n:Prof) RETURN n;'); 
		const records = result.records.map(record => record.get('n').properties);
		console.log('Profs in Neo4j:', records);
		res.json(records); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching profs from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
	
})

router.post('/', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	

	const data = { ...req.body, id: uuidv4() };	
	const keys = Object.keys(data);
	const props = keys.map(key => `${key}: $${key}`).join(', ');
	const query = `CREATE (:Prof {${props}})`;
 
	const session = driver.session();
	// Add new user
	try {
		// Create a new user node
		 await session.run(query, data);
	} catch (error) {
		console.error(error);
		res.status(500).send('Error creating a Prof from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
	res.send(`Prof has been added to the Database`);
})  

router.get('/:id', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const { id } = req.params;

	const session = driver.session();
	try {
		const result = await session.run("MATCH (n:Prof {id: '"+id+"'}) RETURN n;"); 
		const records = result.records.map(record => record.get('n').properties);
		console.log('Prof ${id} in Neo4j:', records);
		res.json(records); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching Prof from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
});

router.delete('/:id', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const { id } = req.params;

	const session = driver.session();
	try {
		const result = await session.run("MATCH (n:Prof {id: '"+id+"'}) DETACH DELETE n;"); 
		console.log(result);
		res.json(result); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching Prof from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
});

export default router