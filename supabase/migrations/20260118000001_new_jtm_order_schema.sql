-- ============================================
-- JTM ORDER - New Schema Migration
-- Drops old tables and recreates with new structure
-- ============================================

-- Drop old tables if they exist (in reverse dependency order)
DROP TABLE IF EXISTS sales_plans CASCADE;
DROP TABLE IF EXISTS master_products CASCADE;
DROP TABLE IF EXISTS master_regions CASCADE;
DROP TYPE IF EXISTS product_category CASCADE;

-- Drop old function
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- ============================================
-- Core Tables
-- ============================================

-- Table: branches (Cabang)
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode VARCHAR(20) NOT NULL,
    nama VARCHAR(100) NOT NULL,
    alamat TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_branches_kode UNIQUE (kode)
);

-- Table: products (Persediaan/Barang)
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode_barang VARCHAR(50) NOT NULL,
    tipe VARCHAR(100),
    nama VARCHAR(255) NOT NULL,
    deskripsi TEXT,
    harga DECIMAL(15, 2) DEFAULT 0,
    stock INTEGER DEFAULT 0,
    satuan VARCHAR(20) DEFAULT 'PCS',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_products_kode UNIQUE (kode_barang),
    CONSTRAINT chk_harga_positive CHECK (harga >= 0),
    CONSTRAINT chk_stock_positive CHECK (stock >= 0)
);

CREATE INDEX IF NOT EXISTS idx_products_kode ON products(kode_barang);
CREATE INDEX IF NOT EXISTS idx_products_nama ON products(nama);

-- ============================================
-- Purchase Orders
-- ============================================

DO $$ BEGIN
    CREATE TYPE po_status AS ENUM ('draft', 'pending', 'approved', 'partial', 'received', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number VARCHAR(50) NOT NULL,
    branch_id UUID NOT NULL,
    tanggal DATE NOT NULL,
    status po_status DEFAULT 'draft',
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_po_number UNIQUE (po_number),
    CONSTRAINT fk_po_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT fk_po_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL,
    product_id UUID NOT NULL,
    qty_ordered INTEGER NOT NULL DEFAULT 0,
    qty_received INTEGER DEFAULT 0,
    harga_satuan DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_poi_po FOREIGN KEY (po_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- ============================================
-- Goods Receipt
-- ============================================

CREATE TABLE IF NOT EXISTS goods_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gr_number VARCHAR(50) NOT NULL,
    po_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    tanggal_terima DATE NOT NULL,
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uk_gr_number UNIQUE (gr_number),
    CONSTRAINT fk_gr_po FOREIGN KEY (po_id) REFERENCES purchase_orders(id) ON DELETE RESTRICT,
    CONSTRAINT fk_gr_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT fk_gr_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS goods_receipt_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gr_id UUID NOT NULL,
    poi_id UUID NOT NULL,
    qty_received INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_gri_gr FOREIGN KEY (gr_id) REFERENCES goods_receipts(id) ON DELETE CASCADE,
    CONSTRAINT fk_gri_poi FOREIGN KEY (poi_id) REFERENCES purchase_order_items(id) ON DELETE RESTRICT
);

-- ============================================
-- Sales
-- ============================================

CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    bulan_tahun DATE NOT NULL,
    qty_sold INTEGER NOT NULL DEFAULT 0,
    harga_jual DECIMAL(15, 2) DEFAULT 0,
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_sales_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sales_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sales_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT uk_sales_branch_product_month UNIQUE (branch_id, product_id, bulan_tahun)
);

-- ============================================
-- Sales Plan
-- ============================================

CREATE TABLE IF NOT EXISTS sales_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    bulan_tahun DATE NOT NULL,
    target INTEGER DEFAULT 0,
    estimasi INTEGER DEFAULT 0,
    realisasi INTEGER DEFAULT 0,
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_sp_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sp_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sp_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT uk_sp_product_branch_month UNIQUE (product_id, branch_id, bulan_tahun)
);

-- ============================================
-- User Profiles
-- ============================================

CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- Triggers & Functions
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_products_updated_at ON products;
CREATE TRIGGER trigger_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_branches_updated_at ON branches;
CREATE TRIGGER trigger_branches_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_po_updated_at ON purchase_orders;
CREATE TRIGGER trigger_po_updated_at BEFORE UPDATE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_sales_updated_at ON sales;
CREATE TRIGGER trigger_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_sp_updated_at ON sales_plans;
CREATE TRIGGER trigger_sp_updated_at BEFORE UPDATE ON sales_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trigger_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'user')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- RLS Policies
-- ============================================

ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Read policies
CREATE POLICY "Read branches" ON branches FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read products" ON products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read PO" ON purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read PO items" ON purchase_order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read GR" ON goods_receipts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read GR items" ON goods_receipt_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read sales" ON sales FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read sales plans" ON sales_plans FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read profiles" ON user_profiles FOR SELECT TO authenticated USING (true);

-- Write policies
CREATE POLICY "Manage products" ON products FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage PO" ON purchase_orders FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage PO items" ON purchase_order_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage GR" ON goods_receipts FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage GR items" ON goods_receipt_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage sales" ON sales FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Manage sales plans" ON sales_plans FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Admin policies
CREATE POLICY "Admin manage branches" ON branches FOR ALL TO authenticated 
    USING (true) WITH CHECK (true);

CREATE POLICY "Admin manage profiles" ON user_profiles FOR ALL TO authenticated 
    USING (true) WITH CHECK (true);

-- Service role access
CREATE POLICY "Service branches" ON branches FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service profiles" ON user_profiles FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- Seed Data
-- ============================================

INSERT INTO branches (kode, nama, alamat) VALUES
    ('HO', 'Head Office', 'Jakarta'),
    ('SBY', 'Surabaya', 'Jawa Timur'),
    ('MLG', 'Malang', 'Jawa Timur'),
    ('KDR', 'Kediri', 'Jawa Timur'),
    ('JBR', 'Jember', 'Jawa Timur')
ON CONFLICT (kode) DO NOTHING;

INSERT INTO products (kode_barang, tipe, nama, deskripsi, harga, stock, satuan) VALUES
    ('PRD001', 'NS-40-ZL', 'Aki NS-40-ZL', 'Aki mobil NS-40 kiri', 450000, 100, 'PCS'),
    ('PRD002', 'NS-60-L', 'Aki NS-60-L', 'Aki mobil NS-60 kiri', 650000, 80, 'PCS'),
    ('PRD003', 'NS-70-L', 'Aki NS-70-L', 'Aki mobil NS-70 kiri', 750000, 60, 'PCS'),
    ('PRD004', 'N-50-Z', 'Aki N-50-Z', 'Aki mobil N-50 Z', 550000, 70, 'PCS'),
    ('PRD005', 'YTZ5S', 'Aki Motor YTZ5S', 'Aki motor kering YTZ5S', 180000, 200, 'PCS')
ON CONFLICT (kode_barang) DO NOTHING;
