-- ============================================
-- Stock Movements Table for tracking stock history
-- ============================================

-- Type of stock movement
DO $$ BEGIN
    CREATE TYPE movement_type AS ENUM ('IN', 'OUT', 'ADJUSTMENT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Table: stock_movements
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    movement_type VARCHAR(20) NOT NULL CHECK (movement_type IN ('IN', 'OUT', 'ADJUSTMENT')),
    qty INTEGER NOT NULL,
    qty_before INTEGER NOT NULL DEFAULT 0,
    qty_after INTEGER NOT NULL DEFAULT 0,
    reference_type VARCHAR(50), -- PO, GR, SALE, MANUAL
    reference_id UUID,
    reference_number VARCHAR(100),
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_sm_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sm_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
    CONSTRAINT fk_sm_created_by FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_branch ON stock_movements(branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON stock_movements(created_at DESC);

-- RLS
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read stock movements" ON stock_movements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Manage stock movements" ON stock_movements FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- Stock per Branch Table
-- ============================================

CREATE TABLE IF NOT EXISTS product_stocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    CONSTRAINT uk_product_branch UNIQUE (product_id, branch_id),
    CONSTRAINT chk_stock_positive CHECK (stock >= 0)
);

-- RLS
ALTER TABLE product_stocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read product stocks" ON product_stocks FOR SELECT TO authenticated USING (true);
CREATE POLICY "Manage product stocks" ON product_stocks FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Function to update stock after movement
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Upsert into product_stocks
    INSERT INTO product_stocks (product_id, branch_id, stock, updated_at)
    VALUES (NEW.product_id, NEW.branch_id, NEW.qty_after, NOW())
    ON CONFLICT (product_id, branch_id)
    DO UPDATE SET 
        stock = NEW.qty_after,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_stock_after_movement ON stock_movements;
CREATE TRIGGER trigger_update_stock_after_movement
    AFTER INSERT ON stock_movements
    FOR EACH ROW EXECUTE FUNCTION update_product_stock();
