const prisma = require('./src/config/prisma');

async function testPrismaReal() {
  try {
    const users = await prisma.user.findMany();
    console.log('PRISMA SUCCESS! Existing Users in DB:', users.length);
  } catch (err) {
    console.error('Prisma Error:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

testPrismaReal();
