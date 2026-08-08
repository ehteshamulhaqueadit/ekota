const prisma = require('./src/config/prisma');

async function testDb() {
  try {
    await prisma.$connect();
    console.log('PostgreSQL connection SUCCESSFUL!');
  } catch (err) {
    console.log('PostgreSQL connection FAILED:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

testDb();
