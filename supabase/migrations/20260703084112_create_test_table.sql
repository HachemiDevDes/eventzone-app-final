CREATE TABLE IF NOT EXISTS antigravity_test_table (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO antigravity_test_table (message) VALUES ('Hello from Antigravity! I successfully controlled your database directly from my workspace!');
