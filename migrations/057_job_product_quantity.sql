-- Migration 057: Quantity on job_products + anon read for factory portal bulk forecast

ALTER TABLE job_products ADD COLUMN IF NOT EXISTS quantity integer DEFAULT 0;

-- Allow factory portal (anon) to read jobs and job_products for bulk-orders forecast
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'jobs' AND policyname = 'jobs_anon_read'
    ) THEN
        CREATE POLICY "jobs_anon_read" ON jobs FOR SELECT TO anon USING (true);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'job_products' AND policyname = 'job_products_anon_read'
    ) THEN
        CREATE POLICY "job_products_anon_read" ON job_products FOR SELECT TO anon USING (true);
    END IF;
END $$;
