-- Migration 052: Fix null brand_id on design_stages + RLS repair + save RPC
-- Root cause: stage 5 (Upload To Drive) rows were created without brand_id in some
-- code paths. RLS checks brand_id IN (...), and NULL IN (list) = NULL (falsy), so
-- those rows are invisible to all queries — reads return nothing, updates silently fail.

-- ── Step 1: Backfill brand_id on any design_stages rows that have brand_id = NULL ──
UPDATE design_stages ds
SET brand_id = dt.brand_id
FROM design_tasks dt
WHERE ds.task_id = dt.id
  AND ds.brand_id IS NULL
  AND dt.brand_id IS NOT NULL;

-- ── Step 2: Update RLS policies to also allow access via task ownership ──
-- This ensures that if brand_id is ever null again (e.g. a race or legacy row),
-- access is still granted when the linked design_task belongs to the user's brand.

DROP POLICY IF EXISTS "brand_read_design_stages" ON design_stages;
CREATE POLICY "brand_read_design_stages" ON design_stages
    FOR SELECT USING (
        brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (
                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
            )
        )
        OR (brand_id IS NULL AND task_id IN (
            SELECT id FROM design_tasks WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        ))
    );

DROP POLICY IF EXISTS "brand_write_design_stages" ON design_stages;
CREATE POLICY "brand_write_design_stages" ON design_stages
    FOR ALL USING (
        brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (
                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
            )
        )
        OR (brand_id IS NULL AND task_id IN (
            SELECT id FROM design_tasks WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        ))
    );

-- ── Step 3: SECURITY DEFINER RPC for reliable drive URL upsert ──
-- Called from JS as a fallback when the direct update is blocked by RLS.
-- Validates that the calling user owns the task's brand before writing.
CREATE OR REPLACE FUNCTION upsert_stage5_drive_url(
    p_task_id   uuid,
    p_brand_id  uuid,
    p_drive_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Verify caller owns this task (prevents cross-tenant writes)
    IF NOT EXISTS (
        SELECT 1 FROM design_tasks
        WHERE id = p_task_id
          AND brand_id = p_brand_id
          AND p_brand_id IN (
              SELECT brand_id FROM user_profiles WHERE id = auth.uid()
              UNION
              SELECT id FROM brands WHERE EXISTS (
                  SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
              )
          )
    ) THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    -- Upsert stage 5, always setting brand_id and drive_url
    INSERT INTO design_stages (task_id, brand_id, stage_number, stage_name, status, concept_statuses)
    VALUES (
        p_task_id, p_brand_id, 5, 'Upload To Drive', 'not_started',
        jsonb_build_object('drive_url', p_drive_url)
    )
    ON CONFLICT (task_id, stage_number) DO UPDATE
        SET brand_id          = p_brand_id,
            concept_statuses  = jsonb_set(
                COALESCE(design_stages.concept_statuses, '{}'),
                '{drive_url}',
                to_jsonb(p_drive_url)
            ),
            updated_at        = now();
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_stage5_drive_url(uuid, uuid, text) TO authenticated;
