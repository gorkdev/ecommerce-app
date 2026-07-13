/*
  Warnings:

  - Added the required column `updatedAt` to the `DeviceToken` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "DeviceToken" ADD COLUMN     "locale" TEXT NOT NULL DEFAULT 'en',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;
