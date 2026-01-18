-- ============================================
-- YUASA Sales Forecasting & Inventory Planning
-- Migration 003: Row Level Security (RLS) Policies
-- ============================================

-- ============================================
-- Enable RLS on all tables
-- ============================================
ALTER TABLE master_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_plans ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Policies for master_products
-- ============================================

-- Anyone authenticated can read products
CREATE POLICY "Allow authenticated users to read products"
    ON master_products
    FOR SELECT
    TO authenticated
    USING (true);

-- Only service role can insert products (admin operation)
CREATE POLICY "Allow service role to insert products"
    ON master_products
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Only service role can update products
CREATE POLICY "Allow service role to update products"
    ON master_products
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Only service role can delete products
CREATE POLICY "Allow service role to delete products"
    ON master_products
    FOR DELETE
    TO service_role
    USING (true);

-- ============================================
-- Policies for master_regions
-- ============================================

-- Anyone authenticated can read regions
CREATE POLICY "Allow authenticated users to read regions"
    ON master_regions
    FOR SELECT
    TO authenticated
    USING (true);

-- Only service role can manage regions
CREATE POLICY "Allow service role to insert regions"
    ON master_regions
    FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Allow service role to update regions"
    ON master_regions
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow service role to delete regions"
    ON master_regions
    FOR DELETE
    TO service_role
    USING (true);

-- ============================================
-- Policies for sales_plans
-- ============================================

-- Authenticated users can read all sales plans
CREATE POLICY "Allow authenticated users to read sales plans"
    ON sales_plans
    FOR SELECT
    TO authenticated
    USING (true);

-- Authenticated users can insert sales plans (with their user id)
CREATE POLICY "Allow authenticated users to insert sales plans"
    ON sales_plans
    FOR INSERT
    TO authenticated
    WITH CHECK (
        created_by = auth.uid() OR created_by IS NULL
    );

-- Authenticated users can update any sales plans
-- (In production, you may want to restrict this to owner or specific roles)
CREATE POLICY "Allow authenticated users to update sales plans"
    ON sales_plans
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Only service role or record owner can delete
CREATE POLICY "Allow owner or service role to delete sales plans"
    ON sales_plans
    FOR DELETE
    TO authenticated
    USING (
        created_by = auth.uid()
    );

CREATE POLICY "Allow service role full delete access"
    ON sales_plans
    FOR DELETE
    TO service_role
    USING (true);

-- ============================================
-- Grant access to the view
-- ============================================
GRANT SELECT ON v_sales_plans_detail TO authenticated;
GRANT SELECT ON v_sales_plans_detail TO anon;

-- ============================================
-- Comments
-- ============================================
COMMENT ON POLICY "Allow authenticated users to read products" ON master_products 
    IS 'All authenticated users can view product catalog';
    
COMMENT ON POLICY "Allow authenticated users to read sales plans" ON sales_plans 
    IS 'All authenticated users can view sales planning data for reporting';
    
COMMENT ON POLICY "Allow authenticated users to insert sales plans" ON sales_plans 
    IS 'Users can create new sales plan entries';
    
COMMENT ON POLICY "Allow authenticated users to update sales plans" ON sales_plans 
    IS 'Users can update sales plan entries (for collaborative editing)';
