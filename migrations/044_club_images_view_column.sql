-- Add view column to club_images to store which view each file represents (front, back, side, etc.)
ALTER TABLE club_images ADD COLUMN IF NOT EXISTS view text NOT NULL DEFAULT 'front';

-- Remove duplicate rows caused by earlier uploads that used (club_id, product_id) as the key,
-- resulting in the same file being stored multiple times. Keep the physically last-inserted
-- row per (club_id, file_name) pair using ctid (works with UUID primary keys).
DELETE FROM club_images a
USING club_images b
WHERE a.club_id = b.club_id
  AND a.file_name = b.file_name
  AND a.ctid < b.ctid;

-- Replace the old (club_id, product_id) unique constraint with one keyed on file_name.
-- Using (club_id, file_name) is simpler and handles all cases: multiple views per product,
-- multiple listings, multiple variants — each file is unique within a club regardless of
-- product_id or view.
ALTER TABLE club_images DROP CONSTRAINT IF EXISTS club_images_club_id_product_id_key;
ALTER TABLE club_images DROP CONSTRAINT IF EXISTS club_images_club_id_product_id_view_key;

ALTER TABLE club_images ADD CONSTRAINT club_images_club_id_file_name_key
  UNIQUE (club_id, file_name);
