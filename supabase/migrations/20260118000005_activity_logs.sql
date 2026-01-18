-- ============================================
-- Activity Logs Table for audit trail
-- ============================================

CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module VARCHAR(50) NOT NULL, -- 'products', 'purchase_orders', 'stock', etc.
    action VARCHAR(50) NOT NULL, -- 'create', 'update', 'delete', 'stock_in', 'stock_out', etc.
    entity_id UUID, -- ID of the affected record
    entity_name VARCHAR(255), -- Name/code of the entity for display
    description TEXT NOT NULL, -- Human readable description
    old_value JSONB, -- Previous value (for updates)
    new_value JSONB, -- New value (for creates/updates)
    user_id UUID,
    user_name VARCHAR(255),
    branch_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT fk_al_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_activity_logs_module ON activity_logs(module);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_id ON activity_logs(entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);

-- RLS
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read activity logs" ON activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert activity logs" ON activity_logs FOR INSERT TO authenticated WITH CHECK (true);
