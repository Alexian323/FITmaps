import neo4j from 'neo4j-driver';

const driver = neo4j.driver(
  'bolt://localhost:7687',
  neo4j.auth.basic('neo4j', 'Navigator')
);

const session = driver.session();
const result = await session.run('MATCH (n) RETURN n LIMIT 5');
console.log(result.records);
await session.close();
await driver.close();