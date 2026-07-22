/*
  Warnings:

  - A unique constraint covering the columns `[userAId,userBId,sport]` on the table `Match` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `sport` to the `Match` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "Match_userAId_userBId_key";

-- AlterTable
ALTER TABLE "Match" ADD COLUMN     "sport" "Sport" NOT NULL;

-- CreateIndex
CREATE INDEX "Match_userAId_idx" ON "Match"("userAId");

-- CreateIndex
CREATE INDEX "Match_userBId_idx" ON "Match"("userBId");

-- CreateIndex
CREATE UNIQUE INDEX "Match_userAId_userBId_sport_key" ON "Match"("userAId", "userBId", "sport");

-- AddForeignKey
ALTER TABLE "Message" ADD CONSTRAINT "Message_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
