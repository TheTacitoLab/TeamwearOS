-- Migration 065: Factory Key Documents
-- A simple per-brand document library shown in the factory area (internal TOS
-- tab + public token-gated factory/view.html). Each entry has a title, a short
-- description, and either an uploaded file or an external clickable URL.

CREATE TABLE IF NOT EXISTS factory_documents (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id         uuid REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    title            text NOT NULL,
    description      text,
    doc_type         text NOT NULL DEFAULT 'file',   -- 'file' | 'url'
    file_url         text NOT NULL,                   -- storage public URL or external URL
    file_name        text,
    file_type        text,
    file_size        bigint,
    sort_order       integer NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    created_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_factory_documents_brand ON factory_documents(brand_id);

ALTER TABLE factory_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "factory_documents_auth" ON factory_documents;
CREATE POLICY "factory_documents_auth" ON factory_documents FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- Anon (public factory link) can read documents — token-as-credential model.
DROP POLICY IF EXISTS "factory_documents_anon_read" ON factory_documents;
CREATE POLICY "factory_documents_anon_read" ON factory_documents FOR SELECT TO anon USING (true);
