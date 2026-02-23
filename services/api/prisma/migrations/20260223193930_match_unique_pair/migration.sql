/*
  Warnings:

  - You are about to drop the column `sport` on the `Match` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[userAId,userBId]` on the table `Match` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "Match_userAId_userBId_sport_key";

-- AlterTable
ALTER TABLE "Match" DROP COLUMN "sport";

-- CreateIndex
CREATE UNIQUE INDEX "Match_userAId_userBId_key" ON "Match"("userAId", "userBId");
