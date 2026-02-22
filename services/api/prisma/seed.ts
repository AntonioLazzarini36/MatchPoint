import "dotenv/config";
import { PrismaClient, Sport } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  // limpia (dev)
  await prisma.refreshToken.deleteMany();
  await prisma.preferences.deleteMany();
  await prisma.profile.deleteMany();
  await prisma.user.deleteMany();

  const people = [
    { displayName: "Alex", birthDate: new Date("2001-01-06"), city: "Vienna", sports: [Sport.TENNIS], bio: "Looking for a solid rally partner." },
    { displayName: "Marta", birthDate: new Date("2002-05-24"), city: "Vienna", sports: [Sport.RUNNING], bio: "Easy runs + coffee." },
    { displayName: "Leo", birthDate: new Date("1994-09-15"), city: "Vienna", sports: [Sport.TENNIS], bio: "Competitive sets, weekends." },
    { displayName: "Sara", birthDate: new Date("1996-03-29"), city: "Vienna", sports: [Sport.RUNNING], bio: "Tempo runs, 10k focus." },
  ];

  for (const p of people) {
    await prisma.user.create({
      data: {
        email: `${p.displayName.toLowerCase()}@test.com`,
        passwordHash: "dev",
        profile: {
          create: {
            displayName: p.displayName,
            birthDate: p.birthDate,
            city: p.city,
            bio: p.bio,
            photos: [],
            sports: p.sports,
          },
        },
        preferences: {
          create: { sportsWanted: p.sports },
        },
      },
    });
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });