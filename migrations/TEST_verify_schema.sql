-- =============================================
-- Schema Verification Tests — TeamwearOS
-- Run this in Supabase SQL Editor after applying
-- all migrations (001 → 013).
--
-- Each SELECT should return rows marked PASS.
-- Any FAIL row indicates a missing table, column,
-- constraint, policy, or function.
-- =============================================

-- ──────────────────────────────────────────
-- 1. TABLES — all expected tables must exist
-- ──────────────────────────────────────────
SELECT
    t.table_name,
    CASE WHEN t.table_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    ('brands'),
    ('clubs'),
    ('club_teams'),
    ('club_products'),
    ('club_activity'),
    ('jobs'),
    ('job_teams'),
    ('job_activity'),
    ('design_tasks'),
    ('design_versions'),
    ('design_annotations'),
    ('design_feed'),
    ('design_task_assets'),
    ('design_task_delivery'),
    ('design_brief_log'),
    ('leads'),
    ('lead_contacts'),
    ('lead_activity'),
    ('kanban_stages'),
    ('feature_toggles'),
    ('order_forms'),
    ('order_submissions'),
    ('order_submission_items'),
    ('purchase_orders'),
    ('po_line_items'),
    ('user_profiles'),
    ('user_feature_permissions'),
    ('brand_pricing_tiers'),
    ('brand_shopify_tags')
) AS expected(table_name)
LEFT JOIN information_schema.tables t
    ON t.table_name = expected.table_name
    AND t.table_schema = 'public'
ORDER BY result, expected.table_name;


-- ──────────────────────────────────────────
-- 2. KEY COLUMNS — critical columns added by 010 + 011
-- ──────────────────────────────────────────
SELECT
    e.table_name,
    e.column_name,
    CASE WHEN c.column_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    -- From 010
    ('job_activity',  'task_completed'),
    ('job_activity',  'dismissed_by'),
    ('club_activity', 'id'),
    ('club_activity', 'task_completed'),
    ('club_activity', 'dismissed_by'),
    ('lead_activity', 'id'),
    ('lead_activity', 'task_completed'),
    ('leads',         'converted_to_job_id'),
    ('jobs',          'assigned_user_ids'),
    ('clubs',         'assigned_user_ids'),
    ('leads',         'assigned_user_ids'),
    -- From 011
    ('design_tasks',  'brand_id'),
    ('design_tasks',  'task_name'),
    ('design_tasks',  'task_ref'),
    ('design_tasks',  'club_id'),
    ('design_tasks',  'due_date'),
    ('design_tasks',  'job_type'),
    ('design_tasks',  'design_types'),
    ('design_tasks',  'design_brief'),
    ('design_tasks',  'products_required'),
    ('design_tasks',  'assigned_designer_id'),
    ('design_tasks',  'assigned_designer_name'),
    ('design_tasks',  'delivered_at'),
    ('design_tasks',  'completed_at'),
    ('brands',        'design_ref_prefix'),
    ('brands',        'design_task_counter'),
    -- From 013 fixes
    ('design_feed',   'design_task_id'),
    -- From 012
    ('user_profiles', 'username')
) AS e(table_name, column_name)
LEFT JOIN information_schema.columns c
    ON c.table_name = e.table_name
    AND c.column_name = e.column_name
    AND c.table_schema = 'public'
ORDER BY result, e.table_name, e.column_name;


-- ──────────────────────────────────────────
-- 3. RLS ENABLED — all sensitive tables must have RLS on
-- ──────────────────────────────────────────
SELECT
    e.table_name,
    CASE WHEN pt.rowsecurity THEN 'PASS' ELSE 'FAIL — RLS NOT ENABLED' END AS result
FROM (VALUES
    ('clubs'),
    ('club_activity'),
    ('club_teams'),
    ('jobs'),
    ('job_activity'),
    ('design_tasks'),
    ('design_versions'),
    ('design_annotations'),
    ('design_feed'),
    ('design_task_assets'),
    ('design_task_delivery'),
    ('leads'),
    ('lead_activity'),
    ('lead_contacts'),
    ('feature_toggles'),
    ('kanban_stages'),
    ('user_feature_permissions'),
    ('brand_pricing_tiers')
) AS e(table_name)
LEFT JOIN pg_tables pt
    ON pt.tablename = e.table_name
    AND pt.schemaname = 'public'
ORDER BY result, e.table_name;


-- ──────────────────────────────────────────
-- 3b. SECURITY DEFINER functions must have fixed search_path
-- ──────────────────────────────────────────
SELECT
    p.proname AS function_name,
    CASE
        WHEN p.proconfig IS NOT NULL AND EXISTS (
            SELECT 1 FROM unnest(p.proconfig) AS cfg
            WHERE cfg LIKE 'search_path=%'
        ) THEN 'PASS'
        ELSE 'FAIL — mutable search_path (security risk)'
    END AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef = TRUE   -- SECURITY DEFINER only
  AND p.proname IN (
      'handle_new_user',
      'get_next_job_number',
      'increment_design_task_counter'
  )
ORDER BY result, p.proname;


-- ──────────────────────────────────────────
-- 4. RLS POLICIES — key policies must exist
-- ──────────────────────────────────────────
SELECT
    e.tablename,
    e.policyname,
    CASE WHEN p.policyname IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    ('design_tasks',          'brand_access_design_tasks'),
    ('design_tasks',          'brand_write_design_tasks'),
    ('design_versions',       'brand_access_design_versions'),
    ('design_versions',       'brand_write_design_versions'),
    ('design_task_assets',    'brand_access_design_task_assets'),
    ('design_task_assets',    'brand_write_design_task_assets'),
    ('design_task_delivery',  'brand_access_design_task_delivery'),
    ('design_task_delivery',  'brand_write_design_task_delivery'),
    ('club_activity',         'brand_access_club_activity'),
    ('club_activity',         'brand_write_club_activity'),
    ('lead_activity',         'brand_access_lead_activity'),
    ('lead_activity',         'brand_write_lead_activity'),
    ('jobs',                  'brand_access_jobs'),
    ('clubs',                 'brand_access_clubs'),
    ('leads',                 'brand_access_leads')
) AS e(tablename, policyname)
LEFT JOIN pg_policies p
    ON p.tablename = e.tablename
    AND p.policyname = e.policyname
ORDER BY result, e.tablename;


-- ──────────────────────────────────────────
-- 5. FUNCTIONS — RPC functions must exist
-- ──────────────────────────────────────────
SELECT
    e.routine_name,
    CASE WHEN r.routine_name IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    ('increment_design_task_counter'),
    ('get_next_job_number'),
    ('handle_new_user'),
    ('update_updated_at_column')
) AS e(routine_name)
LEFT JOIN information_schema.routines r
    ON r.routine_name = e.routine_name
    AND r.routine_schema = 'public'
ORDER BY result, e.routine_name;


-- ──────────────────────────────────────────
-- 6. CONSTRAINTS — status check values must match app expectations
-- ──────────────────────────────────────────
SELECT
    con.conname AS constraint_name,
    pg_get_constraintdef(con.oid) AS definition,
    CASE
        -- design_tasks should NOT contain 'complete' (old value), MUST have 'completed' and 'delivered'
        WHEN con.conname = 'design_tasks_status_check'
             AND pg_get_constraintdef(con.oid) LIKE '%completed%'
             AND pg_get_constraintdef(con.oid) LIKE '%delivered%'
             AND pg_get_constraintdef(con.oid) NOT LIKE '''complete''%'
             THEN 'PASS'
        -- leads should allow 'converted'
        WHEN con.conname = 'leads_status_check'
             AND pg_get_constraintdef(con.oid) LIKE '%converted%'
             THEN 'PASS'
        -- job_activity should allow 'task'
        WHEN con.conname = 'job_activity_activity_type_check'
             AND pg_get_constraintdef(con.oid) LIKE '%task%'
             THEN 'PASS'
        ELSE 'FAIL — check constraint values'
    END AS result
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE nsp.nspname = 'public'
  AND con.contype = 'c'
  AND con.conname IN (
      'design_tasks_status_check',
      'leads_status_check',
      'job_activity_activity_type_check'
  )
ORDER BY result, con.conname;


-- ──────────────────────────────────────────
-- 7. DATA INTEGRITY — no design_tasks rows should have 'complete' status
-- ──────────────────────────────────────────
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS — no rows with deprecated ''complete'' status'
        ELSE 'FAIL — ' || COUNT(*) || ' row(s) still have status = ''complete'''
    END AS result
FROM design_tasks
WHERE status = 'complete';


-- ──────────────────────────────────────────
-- 8. INDEXES — performance indexes for 010/011/013
-- ──────────────────────────────────────────
SELECT
    e.indexname,
    CASE WHEN i.indexname IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
    ('idx_club_activity_club_id'),
    ('idx_club_activity_brand_id'),
    ('idx_lead_activity_lead_id'),
    ('idx_lead_activity_brand_id'),
    ('idx_jobs_assigned_user_ids'),
    ('idx_clubs_assigned_user_ids'),
    ('idx_leads_assigned_user_ids'),
    ('idx_job_activity_dismissed_by'),
    ('idx_design_tasks_brand'),
    ('idx_design_tasks_club'),
    ('idx_design_tasks_due'),
    ('idx_design_tasks_status'),
    ('idx_design_task_assets_task'),
    ('idx_design_task_assets_brand'),
    ('idx_design_task_delivery_task'),
    ('idx_design_task_delivery_brand'),
    ('idx_design_feed_task')
) AS e(indexname)
LEFT JOIN pg_indexes i
    ON i.indexname = e.indexname
    AND i.schemaname = 'public'
ORDER BY result, e.indexname;
