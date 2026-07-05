-- Rename the transaction table to drop the 'points' prefix
ALTER TABLE IF EXISTS points_transactions RENAME TO transactions;

-- Rename the points column to amount (if it exists)
ALTER TABLE IF EXISTS transactions RENAME COLUMN points TO amount;

-- Remove the obsolete points_balance column from profiles
ALTER TABLE profiles DROP COLUMN IF EXISTS points_balance;
