-- Add view column to club_images to support storing multiple views (front, back, side, etc.)
-- per product per club. Also updates the unique constraint accordingly.
ALTER TABLE club_images ADD COLUMN IF NOT EXISTS view text NOT NULL DEFAULT 'front';

ALTER TABLE club_images DROP CONSTRAINT IF EXISTS club_images_club_id_product_id_key;

ALTER TABLE club_images ADD CONSTRAINT club_images_club_id_product_id_view_key
  UNIQUE (club_id, product_id, view);
