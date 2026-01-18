-- ============================================
-- Suppliers (Pemasok/Principal) Table
-- ============================================

CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode VARCHAR(20) UNIQUE NOT NULL,
    nama VARCHAR(255) NOT NULL,
    alamat TEXT,
    telepon VARCHAR(50),
    email VARCHAR(255),
    kontak_person VARCHAR(255),
    npwp VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add supplier_id to purchase_orders
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL;

-- RLS for suppliers
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read suppliers" ON suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert suppliers" ON suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Update suppliers" ON suppliers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Index
CREATE INDEX IF NOT EXISTS idx_suppliers_kode ON suppliers(kode);
CREATE INDEX IF NOT EXISTS idx_suppliers_nama ON suppliers(nama);
CREATE INDEX IF NOT EXISTS idx_po_supplier ON purchase_orders(supplier_id);

-- Seed some sample suppliers
INSERT INTO suppliers (kode, nama, alamat, telepon, kontak_person) VALUES
('SUP-001', 'PT. Yuasa Battery Indonesia', 'Jl. Raya Bekasi KM. 28, Jakarta', '021-8900123', 'Budi Santoso'),
('SUP-002', 'PT. GS Astra Battery', 'Jl. Industri Cikarang, Bekasi', '021-8901234', 'Ahmad Yani'),
('SUP-003', 'PT. Incoe Inti Nusa', 'Jl. Pulogadung No. 10, Jakarta', '021-4891234', 'Slamet Riyadi')
ON CONFLICT (kode) DO NOTHING;
