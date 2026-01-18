-- Add category to products table
DO $$ BEGIN
    CREATE TYPE product_category AS ENUM ('AMB', 'MCB');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE products ADD COLUMN IF NOT EXISTS kategori VARCHAR(10) DEFAULT 'AMB';

-- Update existing products with categories
UPDATE products SET kategori = 'AMB' WHERE tipe LIKE 'N%' OR tipe LIKE 'NS%';
UPDATE products SET kategori = 'MCB' WHERE tipe LIKE 'YT%';

-- Add check constraint
ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_kategori;
ALTER TABLE products ADD CONSTRAINT chk_kategori CHECK (kategori IN ('AMB', 'MCB'));
