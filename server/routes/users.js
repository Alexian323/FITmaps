import express from 'express';
import neo4j from 'neo4j-driver';

const router = express.Router();

// Getting the list of users 
router.get('/', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	

	const session = driver.session();
	try {
		const result = await session.run('MATCH (u:User) RETURN u, elementId(u) AS elementId;'); 
		const users = result.records.map(record => record.get('u').properties);
		console.log('Users in Neo4j:', users);
		res.json(users); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching users from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
	
})

router.get('/:id', async (req, res) => {
	const driver = neo4j.driver(
	  'bolt://localhost:7687',
	  neo4j.auth.basic('neo4j', 'Navigator')
	);	
    const { id } = req.params;

	const session = driver.session();
	try {
		const result = await session.run("MATCH (u:User {id: '"+id+"'}) RETURN u;"); 
		const users = result.records.map(record => record.get('u').properties);
		console.log('User ${id} in Neo4j:', users);
		res.json(users); // send response
	} catch (error) {
		console.error(error);
		res.status(500).send('Error fetching users from Neo4j');
	} finally {
		await session.close();
		await driver.close();
	}	
});

router.put('/:id', async (req, res) => {
    const driver = neo4j.driver(
        'bolt://localhost:7687',
        neo4j.auth.basic('neo4j', 'Navigator')
    );

	// Prevent neo4J to fail if no data to update
	if (!req.body || Object.keys(req.body).length === 0) {
		return res.status(400).json({
		  error: 'Request body is empty — please provide user data.'
		});
	  }
    
    const userId = req.params.id; // The UUID from the URL
    const updates = req.body;      // The properties to update

    // Combine parameters: the UUID for the MATCH clause and the updates for the SET clause
    const params = {
        id: userId,
        updates: updates 
    };

    const session = driver.session(); 

    try {
        const query = `MATCH (u:User {id: $id}) SET u += $updates RETURN u`;

        const result = await session.run(query, params);

        if (result.records.length === 0) {
            return res.status(404).send(`User with ID ${userId} not found.`);
        }

        const updatedUser = result.records[0].get('u').properties;
        
		console.log(`User ${userId} updated successfully.`);
        res.status(200).json({ message: `User ${userId} updated successfully.`, user: updatedUser });

    } catch (error) {
        console.error('Neo4j Update Error:', error);
        res.status(500).send('Error updating user in Neo4j.');
    } finally {
        await session.close();
        await driver.close(); 
    }
});

router.delete('/:id', (req, res) => {
  const { id } = req.params;

  res.send(`Not implemented yet`);
});

router.post('/', (req, res) => {
    const user = req.body;

    // users.push({ ...user, id: uuidv4() });

    // res.send(`${user.first_name} has been added to the Database`);
})  

export default router