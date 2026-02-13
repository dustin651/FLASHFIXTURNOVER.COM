
-- This script sets up the database schema for the Flash Fix Pro application.
-- To use it, navigate to the SQL Editor in your Supabase project and run this entire script.
-- NOTE: Running this will drop existing objects if they exist to ensure a clean setup.

-- Step 0: Drop existing policies and objects to start fresh
DROP POLICY IF EXISTS "Allow admin full access on jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow admin full access on contractors" ON public.contractors;
DROP POLICY IF EXISTS "Allow admin full access on profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow PMs to read all jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow assigned contractors to read their jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow PMs to create jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow PMs to update jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow assigned contractors to update their job status" ON public.jobs;
DROP POLICY IF EXISTS "Allow authenticated users to read contractors" ON public.contractors;
DROP POLICY IF EXISTS "Allow PMs to create/update contractors" ON public.contractors;
DROP POLICY IF EXISTS "Allow users to view their own profile" ON public.profiles;

DROP TABLE IF EXISTS public.jobs;
DROP TABLE IF EXISTS public.contractors;
DROP TABLE IF EXISTS public.profiles;
DROP FUNCTION IF EXISTS public.handle_new_user;
DROP FUNCTION IF EXISTS public.get_all_users;
DROP FUNCTION IF EXISTS public.delete_user;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Step 1: Create 'profiles' table to store user roles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('pm', 'contractor', 'admin')) NOT NULL
);

-- Step 2: Create a function to automatically create a profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role)
  VALUES (new.id, new.raw_user_meta_data->>'role');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create a trigger to call the function on user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 4: Create the 'contractors' table
CREATE TABLE public.contractors (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  specialty TEXT,
  rating NUMERIC(2, 1) CHECK (rating >= 0 AND rating <= 5),
  avatar TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 5: Create the 'jobs' table
CREATE TABLE public.jobs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  unit TEXT NOT NULL,
  client_name TEXT NOT NULL,
  client_email TEXT,
  address TEXT NOT NULL,
  service_type TEXT NOT NULL,
  service_date DATE NOT NULL,
  lockbox TEXT,
  status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed')),
  checklist_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  contractor_id BIGINT REFERENCES public.contractors(id) ON DELETE SET NULL
);

-- Step 6: Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS Policies for 'profiles'
CREATE POLICY "Allow admin full access on profiles" ON public.profiles
  FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "Allow users to view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Step 8: Create RLS Policies for 'contractors'
CREATE POLICY "Allow admin full access on contractors" ON public.contractors
  FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "Allow authenticated users to read contractors" ON public.contractors
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow PMs to create/update contractors" ON public.contractors
  FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'pm');

-- Step 9: Create RLS Policies for 'jobs'
CREATE POLICY "Allow admin full access on jobs" ON public.jobs
  FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "Allow PMs to read all jobs" ON public.jobs
  FOR SELECT USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'pm');
CREATE POLICY "Allow assigned contractors to read their jobs" ON public.jobs
  FOR SELECT USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'contractor' 
    AND contractor_id IN (SELECT id FROM public.contractors WHERE user_id = auth.uid()));
CREATE POLICY "Allow PMs to create jobs" ON public.jobs
  FOR INSERT WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'pm');
CREATE POLICY "Allow PMs to update jobs" ON public.jobs
  FOR UPDATE USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'pm');
CREATE POLICY "Allow assigned contractors to update their job status" ON public.jobs
  FOR UPDATE USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'contractor' 
    AND contractor_id IN (SELECT id FROM public.contractors WHERE user_id = auth.uid()));


-- Step 10: Create Admin-Only RPC functions for User Management

-- Function to get all users (admin only)
CREATE OR REPLACE FUNCTION get_all_users()
RETURNS TABLE (
  id uuid,
  email text,
  role text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if the calling user is an admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can view all users';
  END IF;

  RETURN QUERY
  SELECT u.id, u.email, p.role, u.created_at
  FROM auth.users u
  JOIN public.profiles p ON u.id = p.id;
END;
$$;

-- Function to delete a user (admin only)
CREATE OR REPLACE FUNCTION delete_user(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if the calling user is an admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can delete users';
  END IF;

  DELETE FROM auth.users WHERE id = user_id;
END;
$$;


-- Step 11: Insert sample contractor data
INSERT INTO public.contractors (name, specialty, rating, avatar) VALUES
('Mike''s Maintenance', 'General Repair', 4.8, 'M'),
('Cleaning Crew Co.', 'Deep Cleaning', 4.9, 'C'),
('Sparkle & Shine', 'Standard Cleaning', 4.7, 'S');

-- Note on Creating an Admin:
-- To create an admin user, you can either:
-- 1. Sign up a new user and select the 'Platform Admin' role.
-- 2. Manually update an existing user's role in the 'profiles' table.
--    Example: UPDATE public.profiles SET role = 'admin' WHERE id = 'user-uuid-to-promote';

-- End of script.
