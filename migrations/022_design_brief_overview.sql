-- Migration 022: Design Brief Overview — new task fields + club hex colours
-- Adds structured fields needed for the visual brief dashboard in Design Studio.

-- New design_tasks fields
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS team          text,
    ADD COLUMN IF NOT EXISTS order_type    text
        CHECK (order_type IN ('match_kit','training_range','travel_range','leisurewear','other')),
    ADD COLUMN IF NOT EXISTS season_event  text,
    ADD COLUMN IF NOT EXISTS priority      text DEFAULT 'standard'
        CHECK (priority IN ('standard','high','urgent')),
    ADD COLUMN IF NOT EXISTS use_club_colours boolean DEFAULT true,
    ADD COLUMN IF NOT EXISTS custom_colours   jsonb DEFAULT '{}';

-- Hex colour fields on clubs (pantone fields already exist from migration 004/006;
-- hex values are stored separately since Pantone→hex conversion requires manual input)
ALTER TABLE clubs
    ADD COLUMN IF NOT EXISTS hex_main      text,
    ADD COLUMN IF NOT EXISTS hex_secondary text,
    ADD COLUMN IF NOT EXISTS hex_accent    text;

-- Index for priority filtering
CREATE INDEX IF NOT EXISTS idx_design_tasks_priority ON design_tasks(priority);
