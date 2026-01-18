-- ============================================
-- YUASA Sales Forecasting & Inventory Planning
-- Migration 002: Create Sales Plans Table
-- ============================================

-- ============================================
-- Table: sales_plans
-- Stores monthly sales planning data per product per region
-- This is the main transactional table
-- ============================================
CREATE TABLE IF NOT EXISTS sales_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    region_id UUID NOT NULL,
    bulan_tahun DATE NOT NULL, -- Always first day of month
    
    -- Planning & Target Data
    target_jual INTEGER DEFAULT 0,
    estimasi_jual INTEGER DEFAULT 0, -- User input: Sales estimate
    realisasi_sales INTEGER DEFAULT 0, -- Actual sales
    
    -- Inventory Data
    stok_awal INTEGER DEFAULT 0, -- Opening stock
    stok_akhir INTEGER DEFAULT 0, -- Closing stock = stok_awal + order_qty - estimasi_jual
    order_qty INTEGER DEFAULT 0, -- Order to factory
    
    -- Metrics
    ito DECIMAL(5,2) DEFAULT 0, -- Inventory Turnover
    
    -- Audit fields
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Foreign Key Constraints
    CONSTRAINT fk_sales_plans_product 
        FOREIGN KEY (product_id) 
        REFERENCES master_products(id) 
        ON DELETE RESTRICT,
        
    CONSTRAINT fk_sales_plans_region 
        FOREIGN KEY (region_id) 
        REFERENCES master_regions(id) 
        ON DELETE RESTRICT,
        
    CONSTRAINT fk_sales_plans_user 
        FOREIGN KEY (created_by) 
        REFERENCES auth.users(id) 
        ON DELETE SET NULL,
    
    -- Unique constraint: One record per product-region-month
    CONSTRAINT uk_sales_plans_product_region_month 
        UNIQUE (product_id, region_id, bulan_tahun),
    
    -- Check constraints for positive values
    CONSTRAINT chk_target_jual_positive CHECK (target_jual >= 0),
    CONSTRAINT chk_estimasi_jual_positive CHECK (estimasi_jual >= 0),
    CONSTRAINT chk_realisasi_sales_positive CHECK (realisasi_sales >= 0),
    CONSTRAINT chk_stok_awal_positive CHECK (stok_awal >= 0),
    CONSTRAINT chk_order_qty_positive CHECK (order_qty >= 0)
);

-- ============================================
-- Indexes for common query patterns
-- ============================================

-- Index for filtering by product
CREATE INDEX idx_sales_plans_product ON sales_plans(product_id);

-- Index for filtering by region
CREATE INDEX idx_sales_plans_region ON sales_plans(region_id);

-- Index for filtering by month/year
CREATE INDEX idx_sales_plans_bulan ON sales_plans(bulan_tahun);

-- Composite index for common query pattern (region + month range)
CREATE INDEX idx_sales_plans_region_bulan ON sales_plans(region_id, bulan_tahun);

-- Composite index for product listings per region
CREATE INDEX idx_sales_plans_product_region ON sales_plans(product_id, region_id);

-- ============================================
-- Trigger for auto-update timestamp
-- ============================================
CREATE TRIGGER trigger_sales_plans_updated_at
    BEFORE UPDATE ON sales_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Comments
-- ============================================
COMMENT ON TABLE sales_plans IS 'Monthly sales planning data - stores estimates, targets, and inventory per product per region';
COMMENT ON COLUMN sales_plans.bulan_tahun IS 'Month in DATE format (always first day of month, e.g., 2026-01-01)';
COMMENT ON COLUMN sales_plans.target_jual IS 'Monthly sales target set by management';
COMMENT ON COLUMN sales_plans.estimasi_jual IS 'Estimated sales quantity (user input from Sales Manager)';
COMMENT ON COLUMN sales_plans.realisasi_sales IS 'Actual realized sales for the month';
COMMENT ON COLUMN sales_plans.stok_awal IS 'Opening stock at beginning of month';
COMMENT ON COLUMN sales_plans.stok_akhir IS 'Closing stock = stok_awal + order_qty - estimasi_jual';
COMMENT ON COLUMN sales_plans.order_qty IS 'Order quantity to factory/supplier';
COMMENT ON COLUMN sales_plans.ito IS 'Inventory Turnover ratio';

-- ============================================
-- View: v_sales_plans_detail
-- Denormalized view for easier data retrieval
-- ============================================
CREATE OR REPLACE VIEW v_sales_plans_detail AS
SELECT 
    sp.id,
    sp.bulan_tahun,
    TO_CHAR(sp.bulan_tahun, 'Mon YYYY') AS bulan_label,
    EXTRACT(YEAR FROM sp.bulan_tahun) AS tahun,
    EXTRACT(MONTH FROM sp.bulan_tahun) AS bulan,
    
    -- Product info
    p.id AS product_id,
    p.kode_barang,
    p.nama_produk,
    p.tipe,
    p.kategori,
    p.std_pallet,
    p.isi_dus,
    
    -- Region info
    r.id AS region_id,
    r.kode AS region_kode,
    r.nama AS region_nama,
    
    -- Planning data
    sp.target_jual,
    sp.estimasi_jual,
    sp.realisasi_sales,
    sp.stok_awal,
    sp.stok_akhir,
    sp.order_qty,
    sp.ito,
    
    -- Computed fields
    CASE 
        WHEN sp.target_jual > 0 
        THEN ROUND((sp.estimasi_jual::DECIMAL / sp.target_jual) * 100, 2)
        ELSE 0 
    END AS achievement_pct,
    
    sp.created_at,
    sp.updated_at

FROM sales_plans sp
INNER JOIN master_products p ON sp.product_id = p.id
INNER JOIN master_regions r ON sp.region_id = r.id;

COMMENT ON VIEW v_sales_plans_detail IS 'Denormalized view of sales plans with product and region details';
