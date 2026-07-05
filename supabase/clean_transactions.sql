DELETE FROM transactions WHERE type = 'usage' OR description ILIKE '%%points%%';  
