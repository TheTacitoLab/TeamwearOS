-- ================================================================
-- Migration 012: Username Profiles
-- Adds username field to user_profiles so users can have a clean
-- display name used throughout TeamwearOS (assignments, activity, etc.)
-- ================================================================

-- Add username column to user_profiles
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS username TEXT;

-- Unique username per brand (two users in different brands can share a username)
-- username IS NOT NULL required for uniqueness constraint to apply
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_username_brand
    ON user_profiles(brand_id, username)
    WHERE username IS NOT NULL AND brand_id IS NOT NULL;

-- Allow users to read and update their own username
-- (RLS already exists on user_profiles; this adds update for username)
-- No extra RLS policies needed — existing policies cover the column.

-- Add assigned_to support for leads assignment display
-- (leads.assigned_to already exists as FK to user_profiles)
-- Ensure index for lookup performance
CREATE INDEX IF NOT EXISTS idx_leads_assigned_to ON leads(assigned_to) WHERE assigned_to IS NOT NULL;
