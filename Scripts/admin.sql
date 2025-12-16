CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path = nutrition, public, pg_temp;

set role postgres;

select * from nutrition.users;
-- Регистрация
CREATE OR REPLACE FUNCTION nutrition.user_register(p_username TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE new_id INT;
BEGIN
  IF EXISTS (SELECT 1 FROM nutrition.users WHERE username = p_username) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username already exists');
  END IF;

  INSERT INTO nutrition.users(username, password_hash, role, daily_cal_limit, weekly_cal_limit)
  VALUES (p_username, public.crypt(p_password, public.gen_salt('bf')), 'app_user', 2000, 14000)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('success', true, 'user',
           jsonb_build_object('id', new_id, 'username', p_username, 'role', 'app_user'));
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Registration failed: ' || SQLERRM);
END;
$$;

-- Логин
CREATE OR REPLACE FUNCTION nutrition.user_login(p_username TEXT, p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stored_hash TEXT;
  user_id INT;
  user_role TEXT;
BEGIN
  SELECT id, password_hash, role INTO user_id, stored_hash, user_role
  FROM nutrition.users
  WHERE username = p_username;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid username or password');
  END IF;

  IF public.crypt(p_password, stored_hash) <> stored_hash THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid username or password');
  END IF;

  PERFORM set_config('app.current_user_id', user_id::TEXT, false);
  PERFORM set_config('app.current_user_role', user_role, false);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Login successful',
    'user', jsonb_build_object('id', user_id, 'username', p_username, 'role', user_role)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Login failed: ' || SQLERRM);
END;
$$;