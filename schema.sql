-- Run this in your Supabase SQL editor (in order)

-- 1. Profiles table
CREATE TABLE profiles (
  id      UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email   TEXT,
  name    TEXT,
  school  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own profile read"   ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "own profile insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "own profile update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- 2. Drill sessions table
CREATE TABLE drill_sessions (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mode            TEXT,   -- 'ga' | 'crisis' | 'policy' | 'debate'
  committee       TEXT,
  difficulty      TEXT,
  duration_secs   INTEGER,
  score_content   REAL,
  score_fillers   REAL,
  score_confidence REAL,
  score_hook      REAL,
  overall_score   REAL,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE drill_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own sessions read"   ON drill_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "own sessions insert" ON drill_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. Global stats function (callable by anon users for the home counter)
CREATE OR REPLACE FUNCTION get_global_stats()
RETURNS json LANGUAGE sql SECURITY DEFINER AS $$
  SELECT json_build_object(
    'total_drills',  COUNT(ds.id),
    'total_minutes', COALESCE(FLOOR(SUM(ds.duration_secs) / 60.0), 0)::int,
    'total_schools', COUNT(DISTINCT p.school)
  )
  FROM drill_sessions ds
  LEFT JOIN profiles p ON p.id = ds.user_id
$$;

GRANT EXECUTE ON FUNCTION get_global_stats() TO anon;
