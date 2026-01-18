-- ============================================
-- YUASA Sales Forecasting & Inventory Planning
-- Migration 001: Create Master Tables
-- ============================================

-- Create custom ENUM for product category
CREATE TYPE product_category AS ENUM ('AMB', 'MCB');

-- ============================================
-- Table: master_products
-- Stores master data for Yuasa battery products
-- ============================================
CREATE TABLE IF NOT EXISTS master_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode_barang VARCHAR(50) NOT NULL,
    nama_produk VARCHAR(255),
    tipe VARCHAR(50) NOT NULL,
    kategori product_category NOT NULL,
    std_pallet INTEGER DEFAULT 0,
    isi_dus INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT uk_master_products_kode UNIQUE (kode_barang),
    CONSTRAINT uk_master_products_tipe UNIQUE (tipe),
    CONSTRAINT chk_std_pallet_positive CHECK (std_pallet >= 0),
    CONSTRAINT chk_isi_dus_positive CHECK (isi_dus >= 0)
);

-- Index for faster lookups
CREATE INDEX idx_master_products_kategori ON master_products(kategori);
CREATE INDEX idx_master_products_tipe ON master_products(tipe);

-- Add comment
COMMENT ON TABLE master_products IS 'Master data for Yuasa battery products (AMB=Aki Mobil, MCB=Aki Motor)';
COMMENT ON COLUMN master_products.kode_barang IS 'Unique product code (e.g., YUAMF.001)';
COMMENT ON COLUMN master_products.tipe IS 'Product type specification (e.g., NS-40-ZL)';
COMMENT ON COLUMN master_products.kategori IS 'Product category: AMB (Aki Mobil) or MCB (Aki Motor)';
COMMENT ON COLUMN master_products.std_pallet IS 'Standard quantity per pallet';
COMMENT ON COLUMN master_products.isi_dus IS 'Number of units per box/carton';

-- ============================================
-- Table: master_regions
-- Stores master data for sales regions/branches
-- ============================================
CREATE TABLE IF NOT EXISTS master_regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode VARCHAR(10) NOT NULL,
    nama VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT uk_master_regions_kode UNIQUE (kode)
);

-- Index for active regions lookup
CREATE INDEX idx_master_regions_active ON master_regions(is_active) WHERE is_active = true;

-- Add comment
COMMENT ON TABLE master_regions IS 'Master data for sales regions/branches';
COMMENT ON COLUMN master_regions.kode IS 'Unique region code (e.g., JTM, SBY, KDR)';
COMMENT ON COLUMN master_regions.nama IS 'Full region name';
COMMENT ON COLUMN master_regions.is_active IS 'Whether this region is currently active';

-- ============================================
-- Function: auto_update_timestamp
-- Automatically updates the updated_at column
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for master_products
CREATE TRIGGER trigger_master_products_updated_at
    BEFORE UPDATE ON master_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
