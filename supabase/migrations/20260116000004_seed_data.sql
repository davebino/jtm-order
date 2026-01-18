-- ============================================
-- YUASA Sales Forecasting & Inventory Planning
-- Migration 004: Seed Data (Sample/Dummy Data)
-- ============================================

-- ============================================
-- Insert Master Regions
-- ============================================
INSERT INTO master_regions (kode, nama, is_active) VALUES
    ('JTM', 'Jatim (Jawa Timur)', true),
    ('SBY', 'Surabaya', true),
    ('KDR', 'Kediri', true),
    ('MLG', 'Malang', true),
    ('JBR', 'Jember', true)
ON CONFLICT (kode) DO NOTHING;

-- ============================================
-- Insert Master Products - AMB (Aki Mobil)
-- ============================================
INSERT INTO master_products (kode_barang, nama_produk, tipe, kategori, std_pallet, isi_dus) VALUES
    ('YUAMF.001', 'Yuasa AMB NS-40-ZL', 'NS-40-ZL', 'AMB', 60, 6),
    ('YUAMF.002', 'Yuasa AMB NS-60-L', 'NS-60-L', 'AMB', 48, 4),
    ('YUAMF.003', 'Yuasa AMB NS-70-L', 'NS-70-L', 'AMB', 40, 4),
    ('YUAMF.004', 'Yuasa AMB N-50-Z', 'N-50-Z', 'AMB', 48, 4),
    ('YUAMF.005', 'Yuasa AMB N-70-ZL', 'N-70-ZL', 'AMB', 36, 4),
    ('YUAMF.006', 'Yuasa AMB 55D23L', '55D23L', 'AMB', 48, 4),
    ('YUAMF.007', 'Yuasa AMB 80D26L', '80D26L', 'AMB', 36, 4),
    ('YUAMF.008', 'Yuasa AMB 105D31L', '105D31L', 'AMB', 30, 4),
    ('YUAMF.009', 'Yuasa AMB 32B24-R', '32B24-R', 'AMB', 60, 6),
    ('YUAMF.010', 'Yuasa AMB 38B24-R', '38B24-R', 'AMB', 60, 6)
ON CONFLICT (kode_barang) DO NOTHING;

-- ============================================
-- Insert Master Products - MCB (Aki Motor)
-- ============================================
INSERT INTO master_products (kode_barang, nama_produk, tipe, kategori, std_pallet, isi_dus) VALUES
    ('YUMCB.001', 'Yuasa MCB YTZ4V', 'YTZ4V', 'MCB', 150, 10),
    ('YUMCB.002', 'Yuasa MCB YTZ5S', 'YTZ5S', 'MCB', 120, 10),
    ('YUMCB.003', 'Yuasa MCB YTZ6V', 'YTZ6V', 'MCB', 100, 10),
    ('YUMCB.004', 'Yuasa MCB YTX5L-BS', 'YTX5L-BS', 'MCB', 120, 10),
    ('YUMCB.005', 'Yuasa MCB YTX7A-BS', 'YTX7A-BS', 'MCB', 100, 10),
    ('YUMCB.006', 'Yuasa MCB YTX9-BS', 'YTX9-BS', 'MCB', 80, 8),
    ('YUMCB.007', 'Yuasa MCB YTX12-BS', 'YTX12-BS', 'MCB', 60, 6),
    ('YUMCB.008', 'Yuasa MCB YT7C', 'YT7C', 'MCB', 100, 10),
    ('YUMCB.009', 'Yuasa MCB YTZ4 DRY', 'YTZ4-DRY', 'MCB', 150, 10),
    ('YUMCB.010', 'Yuasa MCB YTZ5 DRY', 'YTZ5-DRY', 'MCB', 120, 10)
ON CONFLICT (kode_barang) DO NOTHING;

-- ============================================
-- Insert Sample Sales Plans Data
-- Generate data for Jan-Mar 2026 for first 5 products in JTM region
-- ============================================

-- Helper: Generate sales plan records
DO $$
DECLARE
    v_jtm_id UUID;
    v_product_id UUID;
    v_kode_barang VARCHAR;
    v_months DATE[] := ARRAY['2026-01-01'::DATE, '2026-02-01'::DATE, '2026-03-01'::DATE];
    v_month DATE;
    v_base_target INTEGER;
    v_random_factor DECIMAL;
BEGIN
    -- Get JTM region ID
    SELECT id INTO v_jtm_id FROM master_regions WHERE kode = 'JTM';
    
    -- Loop through first 5 AMB products
    FOR v_product_id, v_kode_barang IN 
        SELECT id, kode_barang FROM master_products 
        WHERE kategori = 'AMB' 
        ORDER BY kode_barang 
        LIMIT 5
    LOOP
        -- Generate different base targets based on product
        v_base_target := CASE 
            WHEN v_kode_barang = 'YUAMF.001' THEN 500
            WHEN v_kode_barang = 'YUAMF.002' THEN 350
            WHEN v_kode_barang = 'YUAMF.003' THEN 280
            WHEN v_kode_barang = 'YUAMF.004' THEN 420
            WHEN v_kode_barang = 'YUAMF.005' THEN 200
            ELSE 300
        END;
        
        -- Loop through months
        FOREACH v_month IN ARRAY v_months
        LOOP
            v_random_factor := 0.85 + (random() * 0.3); -- 85% to 115%
            
            INSERT INTO sales_plans (
                product_id,
                region_id,
                bulan_tahun,
                target_jual,
                estimasi_jual,
                realisasi_sales,
                stok_awal,
                stok_akhir,
                order_qty,
                ito
            ) VALUES (
                v_product_id,
                v_jtm_id,
                v_month,
                v_base_target,
                ROUND(v_base_target * v_random_factor)::INTEGER,
                CASE 
                    WHEN v_month < CURRENT_DATE 
                    THEN ROUND(v_base_target * (0.9 + random() * 0.2))::INTEGER
                    ELSE 0
                END,
                ROUND(v_base_target * 0.5)::INTEGER, -- stok_awal ~50% of target
                ROUND(v_base_target * 0.4)::INTEGER, -- stok_akhir ~40% of target
                ROUND(v_base_target * 0.8)::INTEGER, -- order ~80% of target
                ROUND((1 + random())::DECIMAL, 2) -- ITO between 1-2
            )
            ON CONFLICT (product_id, region_id, bulan_tahun) DO NOTHING;
        END LOOP;
    END LOOP;
    
    -- Also insert for first 3 MCB products
    FOR v_product_id, v_kode_barang IN 
        SELECT id, kode_barang FROM master_products 
        WHERE kategori = 'MCB' 
        ORDER BY kode_barang 
        LIMIT 3
    LOOP
        v_base_target := CASE 
            WHEN v_kode_barang = 'YUMCB.001' THEN 800
            WHEN v_kode_barang = 'YUMCB.002' THEN 600
            WHEN v_kode_barang = 'YUMCB.003' THEN 450
            ELSE 500
        END;
        
        FOREACH v_month IN ARRAY v_months
        LOOP
            v_random_factor := 0.85 + (random() * 0.3);
            
            INSERT INTO sales_plans (
                product_id,
                region_id,
                bulan_tahun,
                target_jual,
                estimasi_jual,
                realisasi_sales,
                stok_awal,
                stok_akhir,
                order_qty,
                ito
            ) VALUES (
                v_product_id,
                v_jtm_id,
                v_month,
                v_base_target,
                ROUND(v_base_target * v_random_factor)::INTEGER,
                CASE 
                    WHEN v_month < CURRENT_DATE 
                    THEN ROUND(v_base_target * (0.9 + random() * 0.2))::INTEGER
                    ELSE 0
                END,
                ROUND(v_base_target * 0.6)::INTEGER,
                ROUND(v_base_target * 0.5)::INTEGER,
                ROUND(v_base_target * 0.7)::INTEGER,
                ROUND((1 + random())::DECIMAL, 2)
            )
            ON CONFLICT (product_id, region_id, bulan_tahun) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ============================================
-- Verification Queries (for testing)
-- ============================================

-- Verify products were inserted
-- SELECT * FROM master_products ORDER BY kategori, kode_barang;

-- Verify regions were inserted  
-- SELECT * FROM master_regions ORDER BY kode;

-- Verify sales plans were inserted
-- SELECT * FROM v_sales_plans_detail ORDER BY region_kode, kategori, kode_barang, bulan_tahun;

-- Count records
-- SELECT 
--     (SELECT COUNT(*) FROM master_products) AS total_products,
--     (SELECT COUNT(*) FROM master_regions) AS total_regions,
--     (SELECT COUNT(*) FROM sales_plans) AS total_sales_plans;
