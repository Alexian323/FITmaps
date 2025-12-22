import express from 'express';
import neo4j from 'neo4j-driver';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

router.get('/:id', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const { id } = req.params;
    const session = driver.session(); 

    try {
        // Cypher query to MATCH the user and all connected History nodes
        const query = `
            MATCH (u:User {id: $id})-[:RECORDED]->(h:History)
            RETURN h
            ORDER BY h.timestamp DESC
        `;

        const result = await session.run(query, { id });
        
        // Extract properties from the returned History nodes
        const historyRecords = result.records.map(record => record.get('h').properties);
        
        // If no records are found, it returns an empty array, which is an acceptable response (200 OK)
        if (historyRecords.length === 0) {
            // Optional: Check if the user exists before returning a 404, 
            // but returning an empty array is simpler for a GET request.
            return res.status(200).json([]);
        }

        console.log(`History records for User ${id}:`, historyRecords);
        
        res.status(200).json(historyRecords);

    } catch (error) {
        console.error('Neo4j History Read Error:', error);
        res.status(500).send('Error fetching user history from Neo4j.');
    } finally {
        await session.close();
    }
});

router.get('/:id', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const { id } = req.params;

	const session = driver.session();
	try {
		const result = await session.run("MATCH (n:History {id: '"+id+"'}) RETURN n;"); 
		const records = result.records.map(record => record.get('n').properties);
		console.log('History ${id} in Neo4j:', records);
		res.json(records); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching room from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
});

router.post('/:id', async (req, res) => {
    const userId = req.params.id;
    const historyData = { 
        ...req.body, 
        id: uuidv4(), 
        timestamp: new Date().toISOString() 
    };
    
    const params = {
        userId: userId,
        props: historyData
    };

	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const session = driver.session(); 

    try {
        const query = `
            MATCH (u:User {id: $userId})
            CREATE (h:History $props)
            CREATE (u)-[:RECORDED]->(h)
            RETURN h
        `;

        const result = await session.run(query, params);
        
        // Check if the User was found and linked
        if (result.records.length === 0) {
             return res.status(404).send(`User with ID ${userId} not found.`);
        }

        const createdHistory = result.records[0].get('h').properties;
        
        res.status(201).json({ 
            message: `History record created and linked to User ${userId}`,
            history: createdHistory
        });

    } catch (error) {
        console.error('Neo4j Creation Error:', error);
        res.status(500).send('Error creating history record in Neo4j.');
    } finally {
        await session.close();
    }
});

export default router