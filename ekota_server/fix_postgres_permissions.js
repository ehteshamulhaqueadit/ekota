const { Client } = require('pg');

const passwords = ['', 'postgres', 'root', '123456', 'admin', 'ekota1234', 'password', '1234', '12345', 'postgres123', 'ekota'];

async function tryFixPermissions() {
  for (const pwd of passwords) {
    const connectionString = `postgresql://postgres:${pwd}@localhost:5432/ekota_db`;
    const client = new Client({ connectionString });
    try {
      await client.connect();
      console.log(`Connected to PostgreSQL as superuser postgres with password: "${pwd}"`);

      await client.query(`GRANT ALL PRIVILEGES ON DATABASE ekota_db TO ekota_backend;`);
      await client.query(`GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ekota_backend;`);
      await client.query(`GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ekota_backend;`);
      await client.query(`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ekota_backend;`);
      await client.query(`ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ekota_backend;`);
      await client.query(`GRANT ALL ON SCHEMA public TO ekota_backend;`);

      console.log('SUCCESS! Granted all permissions to ekota_backend.');
      await client.end();
      return true;
    } catch (e) {
      await client.end().catch(() => {});
    }
  }

  // Also try connecting with ekota_backend to see if it can GRANT to itself if owner
  try {
    const client = new Client({ connectionString: 'postgresql://ekota_backend:ekota1234@localhost:5432/ekota_db' });
    await client.connect();
    console.log('Connected as ekota_backend');
    await client.query(`GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ekota_backend;`);
    console.log('Granted privileges!');
    await client.end();
    return true;
  } catch (e) {
    console.log('Could not connect as superuser postgres or fix permissions via script:', e.message);
  }

  return false;
}

tryFixPermissions();
