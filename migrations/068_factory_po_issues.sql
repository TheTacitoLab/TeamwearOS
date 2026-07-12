-- Migration 068: Factory PO issues
-- Replaces the single issue_raised/issue_note pair on factory_purchase_orders
-- with a proper child table so a PO can hold multiple issues, each with its
-- own open/resolved status and history.
--
-- The legacy factory_purchase_orders.issue_raised boolean is KEPT as a
-- denormalised "has an open issue" flag so the existing card beacon keeps
-- working without change. issue_note becomes unused.

CREATE TABLE IF NOT EXISTS factory_po_issues (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id       uuid REFERENCES factory_purchase_orders(id) ON DELETE CASCADE NOT NULL,
    brand_id    uuid REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    description text NOT NULL,
    status      text NOT NULL DEFAULT 'open',  -- open | resolved
    created_at  timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT factory_po_issues_status_chk CHECK (status IN ('open','resolved'))
);

CREATE INDEX IF NOT EXISTS idx_factory_po_issues_po    ON factory_po_issues(po_id);
CREATE INDEX IF NOT EXISTS idx_factory_po_issues_brand ON factory_po_issues(brand_id, status);

ALTER TABLE factory_po_issues ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "factory_po_issues_auth" ON factory_po_issues;
CREATE POLICY "factory_po_issues_auth" ON factory_po_issues FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "factory_po_issues_anon_read" ON factory_po_issues;
CREATE POLICY "factory_po_issues_anon_read" ON factory_po_issues FOR SELECT TO anon USING (true);

-- Backfill: migrate any currently-open legacy issues into the new table so
-- nothing is lost on rollout.
INSERT INTO factory_po_issues (po_id, brand_id, description, status, created_at)
SELECT id, brand_id, COALESCE(NULLIF(issue_note, ''), '(no description)'), 'open', created_at
FROM factory_purchase_orders
WHERE issue_raised = true;
