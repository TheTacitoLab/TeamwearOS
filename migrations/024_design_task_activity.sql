-- Migration 024: Design Task Activity
-- Adds user comments and sub-tasks (called "Sub-Tasks") to design task records.
-- These mirror the job_activity system but scoped to individual design tasks.

CREATE TABLE IF NOT EXISTS design_task_activity (
    id              uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id  uuid         NOT NULL REFERENCES design_tasks(id) ON DELETE CASCADE,
    brand_id        uuid         NOT NULL,
    user_id         uuid,
    user_name       text,
    message         text         NOT NULL,
    activity_type   text         NOT NULL DEFAULT 'comment', -- 'comment' | 'sub_task'
    task_completed  boolean      NOT NULL DEFAULT false,
    dismissed_by    uuid[]       DEFAULT '{}',
    created_at      timestamptz  DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_dta_task ON design_task_activity(design_task_id);
CREATE INDEX IF NOT EXISTS idx_dta_brand ON design_task_activity(brand_id);
CREATE INDEX IF NOT EXISTS idx_dta_created ON design_task_activity(created_at DESC);

ALTER TABLE design_task_activity ENABLE ROW LEVEL SECURITY;

-- Brand members (authenticated users whose profile is linked to this brand_id) can manage entries
CREATE POLICY "Brand members can manage design task activity"
    ON design_task_activity FOR ALL
    USING (
        brand_id IN (
            SELECT brand_id FROM profiles WHERE id = auth.uid()
        )
    );
