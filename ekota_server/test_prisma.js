const prisma = require('./src/config/prisma');

async function test() {
  try {
    const producerId = '123e4567-e89b-12d3-a456-426614174000'; // arbitrary valid UUID
    const listings = await prisma.listing.findMany({
      where: { producerId },
      select: {
        campaignStatus: true,
        reviews: {
          select: {
            rating: true,
            authorId: true,
            author: {
              select: {
                role: true
              }
            }
          }
        }
      }
    });
    console.log('Success:', listings);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

test();
