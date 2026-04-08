-- Migration 039: Fix line_order column type in kit_player_details
-- Changes line_order from INTEGER to BIGINT to accommodate Date.now()
-- values (~1.7 trillion ms) which exceed INTEGER max (2,147,483,647).

ALTER TABLE kit_player_details
    ALTER COLUMN line_order TYPE BIGINT;
