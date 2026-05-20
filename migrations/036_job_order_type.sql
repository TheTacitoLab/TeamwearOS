-- Migration 036: Add order_type column to jobs
-- New field: New Order | Repeat Order | Store Build (separate from legacy job_type)

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS order_type TEXT
    CHECK (order_type IN ('new_order','repeat_order','store_build'));

CREATE INDEX IF NOT EXISTS idx_jobs_order_type ON jobs(order_type);
