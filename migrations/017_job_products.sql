-- =============================================
-- Migration 017: Job Products
-- TeamwearOS
-- =============================================
-- Links specific club products to a job so users can select
-- a subset of the club's catalogue for each sales job.
-- Products must already exist in club_products; they cannot
-- be added to a job from the master catalogue directly.
-- =============================================

CREATE TABLE IF NOT EXISTS job_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
    club_product_id UUID REFERENCES club_products(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (job_id, club_product_id)
);

ALTER TABLE job_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "brand_access_job_products" ON job_products
    FOR ALL USING (
        job_id IN (
            SELECT id FROM jobs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );

CREATE INDEX IF NOT EXISTS idx_job_products_job_id ON job_products(job_id);
CREATE INDEX IF NOT EXISTS idx_job_products_club_product_id ON job_products(club_product_id);
