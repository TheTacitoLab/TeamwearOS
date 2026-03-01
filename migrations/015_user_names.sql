-- Migration 015: First Name & Last Name on user_profiles
--
-- Adds first_name and last_name so that assignment dropdowns across
-- design tasks, jobs, clubs, and leads can display a user's full name
-- instead of username or email prefix.
--
-- Default NULL is intentional — existing users set their names via the
-- User Management edit modal. New signups/invites populate from Supabase
-- auth metadata if supplied.

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS first_name TEXT,
    ADD COLUMN IF NOT EXISTS last_name  TEXT;

-- Update the auto-create trigger to carry names from auth metadata.
-- The ON CONFLICT DO NOTHING clause means existing rows are unaffected.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role, first_name, last_name)
  VALUES (
      NEW.id,
      NEW.email,
      'user',
      NEW.raw_user_meta_data->>'first_name',
      NEW.raw_user_meta_data->>'last_name'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
