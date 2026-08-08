const prisma = require('./src/config/prisma');

async function createTables() {
  console.log('Creating database tables in PostgreSQL...');

  const statements = [
    `DO $$ BEGIN CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'VALIDATED', 'FAILED', 'CANCELLED'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
    `DO $$ BEGIN CREATE TYPE "PaymentType" AS ENUM ('RENT', 'INVESTMENT'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
    `DO $$ BEGIN CREATE TYPE "WithdrawalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'PROCESSED'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
    `DO $$ BEGIN CREATE TYPE "WithdrawalMethod" AS ENUM ('BANK_TRANSFER', 'BKASH', 'NAGAD', 'ROCKET'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
    `DO $$ BEGIN CREATE TYPE "NotificationType" AS ENUM ('WITHDRAWAL_APPROVED', 'WITHDRAWAL_REJECTED', 'WITHDRAWAL_PROCESSED', 'PAYMENT_SUCCESS', 'PAYMENT_FAILED', 'GENERAL'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
    `CREATE TABLE IF NOT EXISTS "payments" (
      "id" UUID PRIMARY KEY,
      "user_id" UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "tran_id" VARCHAR(100) UNIQUE NOT NULL,
      "val_id" VARCHAR(100),
      "amount" DECIMAL(12, 2) NOT NULL,
      "currency" VARCHAR(10) DEFAULT 'BDT',
      "payment_type" "PaymentType" NOT NULL,
      "status" "PaymentStatus" DEFAULT 'PENDING',
      "gateway_page_url" TEXT,
      "card_type" VARCHAR(100),
      "bank_tran_id" VARCHAR(100),
      "metadata" JSONB,
      "created_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP,
      "updated_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE TABLE IF NOT EXISTS "producer_balances" (
      "id" UUID PRIMARY KEY,
      "producer_id" UUID UNIQUE NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "total_earnings" DECIMAL(12, 2) DEFAULT 0.00,
      "available_balance" DECIMAL(12, 2) DEFAULT 0.00,
      "pending_withdrawal" DECIMAL(12, 2) DEFAULT 0.00,
      "total_withdrawn" DECIMAL(12, 2) DEFAULT 0.00,
      "created_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP,
      "updated_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE TABLE IF NOT EXISTS "withdrawal_requests" (
      "id" UUID PRIMARY KEY,
      "producer_id" UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "amount" DECIMAL(12, 2) NOT NULL,
      "method" "WithdrawalMethod" NOT NULL,
      "account_details" JSONB NOT NULL,
      "status" "WithdrawalStatus" DEFAULT 'PENDING',
      "admin_note" TEXT,
      "reviewed_by_id" UUID REFERENCES "users"("id") ON DELETE SET NULL,
      "reviewed_at" TIMESTAMPTZ(6),
      "transaction_ref" VARCHAR(100),
      "created_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP,
      "updated_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE TABLE IF NOT EXISTS "notifications" (
      "id" UUID PRIMARY KEY,
      "user_id" UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "title" VARCHAR(255) NOT NULL,
      "message" TEXT NOT NULL,
      "type" "NotificationType" DEFAULT 'GENERAL',
      "is_read" BOOLEAN DEFAULT FALSE,
      "metadata" JSONB,
      "created_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP
    );`
  ];

  try {
    for (const stmt of statements) {
      await prisma.$executeRawUnsafe(stmt);
    }
    console.log('Tables created successfully in PostgreSQL!');
  } catch (err) {
    console.error('Error creating tables:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

createTables();
