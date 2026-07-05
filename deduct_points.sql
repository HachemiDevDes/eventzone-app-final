CREATE OR REPLACE FUNCTION deduct_connection_points(scanner_id UUID, scanned_id UUID, scanner_name TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Deduct from scanner
  UPDATE profiles SET points_balance = points_balance - 1 WHERE id = scanner_id AND points_balance > 0;
  
  -- Deduct from scanned
  UPDATE profiles SET points_balance = points_balance - 1 WHERE id = scanned_id AND points_balance > 0;
  
  -- Insert transactions
  INSERT INTO points_transactions (user_id, type, amount, description) VALUES (scanner_id, 'usage', -1, 'Saved connection');
  INSERT INTO points_transactions (user_id, type, amount, description) VALUES (scanned_id, 'usage', -1, 'Was scanned by: ' || scanner_name);
END;
$$;
