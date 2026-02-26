-- =============================================
-- Migration 009: Record Ownership & Auto User Profile
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Add created_by to clubs table
-- ──────────────────────────────────────────
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ──────────────────────────────────────────
-- Add created_by to jobs table
-- ──────────────────────────────────────────
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ──────────────────────────────────────────
-- Auto-create user_profiles row on auth user signup
-- This ensures new users can log in and see the app
-- (they will have no brand until assigned by a super_admin)
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role)
  VALUES (NEW.id, NEW.email, 'user')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if any, then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: create profiles for any existing auth users who have none
-- (safe to run multiple times due to ON CONFLICT DO NOTHING)
INSERT INTO public.user_profiles (id, email, role)
SELECT au.id, au.email, 'user'
FROM auth.users au
LEFT JOIN public.user_profiles up ON up.id = au.id
WHERE up.id IS NULL
ON CONFLICT (id) DO NOTHING;
