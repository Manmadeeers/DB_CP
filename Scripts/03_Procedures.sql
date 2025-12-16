-- Расширение для crypt/gen_salt
CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET search_path = nutrition, pg_temp;

--------------------------------------------------
-- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ daily_menu
--------------------------------------------------
CREATE OR REPLACE FUNCTION nutrition.ensure_daily_menu(
    p_user_id INT,
    p_date    DATE
) RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    v_week_start  DATE;
    v_weekly_id   INT;
    v_daily_id    INT;
BEGIN
    -- начало недели (понедельник)
    v_week_start := p_date - ((EXTRACT(ISODOW FROM p_date)::INT) - 1);

    -- weekly_menu
    SELECT id INTO v_weekly_id
    FROM nutrition.weekly_menu
    WHERE user_id   = p_user_id
      AND week_start = v_week_start;

    IF v_weekly_id IS NULL THEN
        INSERT INTO nutrition.weekly_menu(user_id, week_start)
        VALUES (p_user_id, v_week_start)
        RETURNING id INTO v_weekly_id;
    END IF;

    -- daily_menu
    SELECT id INTO v_daily_id
    FROM nutrition.daily_menu
    WHERE weekly_menu_id = v_weekly_id
      AND menu_date      = p_date;

    IF v_daily_id IS NULL THEN
        INSERT INTO nutrition.daily_menu(weekly_menu_id, menu_date)
        VALUES (v_weekly_id, p_date)
        RETURNING id INTO v_daily_id;
    END IF;

    RETURN v_daily_id;
END;
$$;

--------------------------------------------------
-- АУТЕНТИФИКАЦИЯ
--------------------------------------------------

-- Регистрация пользователя
CREATE OR REPLACE FUNCTION nutrition.user_register(
    p_username TEXT,
    p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    new_id INT;
BEGIN
    IF EXISTS (SELECT 1 FROM nutrition.users WHERE username = p_username) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Username already exists');
    END IF;

    INSERT INTO nutrition.users (username, password_hash, role, daily_cal_limit, weekly_cal_limit)
    VALUES (p_username, crypt(p_password, gen_salt('bf')), 'app_user', 2000, 14000)
    RETURNING id INTO new_id;

    RETURN jsonb_build_object(
        'success', true,
        'user', jsonb_build_object(
            'id', new_id,
            'username', p_username,
            'role', 'app_user'
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Registration failed: ' || SQLERRM);
END;
$$;
set role postgres;
set role app_admin;
set role app_user;
CREATE OR REPLACE EXTENSION pgcrypto;
SELECT nutrition.user_register('user1111','1111');
SELECT nutrition.user_login('user1111','1111');

-- Логин
CREATE OR REPLACE FUNCTION nutrition.user_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    stored_hash TEXT;
    user_id     INT;
    user_role   TEXT;
BEGIN
    SELECT id, password_hash, role
    INTO user_id, stored_hash, user_role
    FROM nutrition.users
    WHERE username = p_username;
	set role app_admin;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid username or password');
    END IF;

    IF crypt(p_password, stored_hash) <> stored_hash THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid username or password');
    END IF;

    PERFORM set_config('app.current_user_id', user_id::INT, false);
    PERFORM set_config('app.current_user_role', user_role, false);

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Login successful',
        'user', jsonb_build_object(
            'id', user_id,
            'username', p_username,
            'role', user_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Login failed: ' || SQLERRM);
END;
$$;

-- Логаут
CREATE OR REPLACE FUNCTION nutrition.user_logout()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    PERFORM set_config('app.current_user_id', NULL, false);
    PERFORM set_config('app.current_user_role', NULL, false);

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Logout successful'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Logout failed: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- АДМИН: ПОЛЬЗОВАТЕЛИ
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.admin_get_all_users()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied: admin only';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',                 id,
                    'username',           username,
                    'role',               role,
                    'dailyCalorieLimit',  daily_cal_limit,
                    'weeklyCalorieLimit', weekly_cal_limit,
                    'createdAt',          create_at
                )
            )
            FROM nutrition.users

        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to fetch users: ' || SQLERRM);
END;
$$;

-- Экспорт всех пользователей
CREATE OR REPLACE FUNCTION nutrition.admin_export_users()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied: admin only';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',                 id,
                    'username',           username,
                    'role',               role,
                    'dailyCalorieLimit',  daily_cal_limit,
                    'weeklyCalorieLimit', weekly_cal_limit,
                    'createdAt',          create_at
                )
            )
            FROM nutrition.users
            ORDER BY id
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Export users failed: ' || SQLERRM);
END;
$$;

-- Создать админа
CREATE OR REPLACE FUNCTION nutrition.admin_create_admin(
    p_username        TEXT,
    p_password_hash   TEXT,
    p_daily_cal_limit INT DEFAULT 2500,
    p_weekly_cal_limit INT DEFAULT 17500
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    new_admin_id INT;
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    INSERT INTO nutrition.users(username, password_hash, daily_cal_limit, weekly_cal_limit, role)
    VALUES (p_username, p_password_hash, p_daily_cal_limit, p_weekly_cal_limit, 'app_admin')
    RETURNING id INTO new_admin_id;

    RETURN jsonb_build_object(
        'success', true,
        'adminId', new_admin_id,
        'message', 'Administrator created'
    );
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'Username already exists');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Failed to create administrator: ' || SQLERRM);
END;
$$;

-- Удалить админа
CREATE OR REPLACE FUNCTION nutrition.admin_delete_admin(
    p_admin_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    admin_count INT;
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM nutrition.users
        WHERE id = p_admin_id AND role = 'app_admin'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Administrator not found');
    END IF;

    SELECT COUNT(*) INTO admin_count
    FROM nutrition.users
    WHERE role = 'app_admin';

    IF admin_count <= 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot delete the last administrator');
    END IF;

    DELETE FROM nutrition.users WHERE id = p_admin_id;

    RETURN jsonb_build_object('success', true, 'message', 'Administrator deleted');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to delete administrator: ' || SQLERRM);
END;
$$;

-- Создать пользователя
CREATE OR REPLACE FUNCTION nutrition.admin_create_user(
    p_username        TEXT,
    p_password_hash   TEXT,
    p_daily_cal_limit INT,
    p_weekly_cal_limit INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    new_user_id INT;
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    INSERT INTO nutrition.users(username, password_hash, daily_cal_limit, weekly_cal_limit, role)
    VALUES (p_username, p_password_hash, p_daily_cal_limit, p_weekly_cal_limit, 'app_user')
    RETURNING id INTO new_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'userId', new_user_id,
        'message', 'User created'
    );
EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object('success', false, 'error', 'Username already exists');
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Failed to create user: ' || SQLERRM);
END;
$$;
select current_user;
SET ROLE app_admin;

-- Обновить пользователя

CREATE OR REPLACE FUNCTION nutrition.admin_update_user(
    p_user_id         INT,
    p_daily_cal_limit INT,
    p_weekly_cal_limit INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    UPDATE nutrition.users
    SET daily_cal_limit  = p_daily_cal_limit,
        weekly_cal_limit = p_weekly_cal_limit
    WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'User updated');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to update user: ' || SQLERRM);
END;
$$;

-- Удалить пользователя
CREATE OR REPLACE FUNCTION nutrition.admin_delete_user(
    p_user_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    user_role TEXT;
BEGIN
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT role INTO user_role
    FROM nutrition.users
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;

    IF user_role = 'app_admin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Use admin_delete_admin to delete administrators'
        );
    END IF;

    DELETE FROM nutrition.users WHERE id = p_user_id;

    RETURN jsonb_build_object('success', true, 'message', 'User deleted');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to delete user: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- ПРОФИЛЬ / ВЕС
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.get_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'success', true,
            'data', jsonb_build_object(
                'id',                u.id,
                'username',          u.username,
                'dailyCalorieLimit', u.daily_cal_limit,
                'weeklyCalorieLimit',u.weekly_cal_limit
            )
        )
        FROM nutrition.users u
        WHERE u.id = current_setting('app.current_user_id')::INT
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get user info: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.update_my_profile(
    p_daily_cal_limit  INT,
    p_weekly_cal_limit INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    UPDATE nutrition.users
    SET daily_cal_limit  = p_daily_cal_limit,
        weekly_cal_limit = p_weekly_cal_limit
    WHERE id = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object('success', true, 'message', 'Profile updated');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to update user data: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_weight_history()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date',   record_date,
                    'weight', weight
                )
            )
            FROM nutrition.weight_history
            WHERE user_id = current_setting('app.current_user_id')::INT
            ORDER BY record_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get weight history: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.add_weight_record(
    p_date   DATE,
    p_weight NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    INSERT INTO nutrition.weight_history(user_id, record_date, weight)
    VALUES (current_setting('app.current_user_id')::INT, p_date, p_weight)
    ON CONFLICT (user_id, record_date)
    DO UPDATE SET weight = EXCLUDED.weight;

    RETURN jsonb_build_object('success', true, 'message', 'Weight record saved');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to add weight record: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- ПРОДУКТЫ
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.get_available_products()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',                p.id,
                    'name',              p.name,
                    'caloriesPerPortion',p.calories_per_portion,
                    'portionSize',       p.portion_size,
                    'portionUnit',       p.portion_unit,
                    'protein',           p.protein,
                    'fat',               p.fat,
                    'carbs',             p.carbs,
                    'isPublic',          p.is_public
                )
            )
            FROM nutrition.products p
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get products: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_product_by_name(
    p_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',                p.id,
                    'name',              p.name,
                    'caloriesPerPortion',p.calories_per_portion,
                    'portionSize',       p.portion_size,
                    'portionUnit',       p.portion_unit,
                    'protein',           p.protein,
                    'fat',               p.fat,
                    'carbs',             p.carbs,
                    'isPublic',          p.is_public,
                    'createdBy',         p.created_by
                )
            )
            FROM nutrition.products p
            WHERE p.name ILIKE '%' || p_name || '%'
              AND (p.is_public = TRUE OR p.created_by = current_setting('app.current_user_id')::INT)
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to fetch product by name: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.create_product(
    p_name         TEXT,
    p_calories     INT,
    p_portion_size NUMERIC,
    p_portion_unit TEXT,
    p_protein      NUMERIC,
    p_fat          NUMERIC,
    p_carbs        NUMERIC,
    p_is_public    BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    INSERT INTO nutrition.products(
        name, calories_per_portion, portion_size, portion_unit,
        protein, fat, carbs, is_public, created_by
    )
    VALUES (
        p_name, p_calories, p_portion_size, p_portion_unit,
        p_protein, p_fat, p_carbs, p_is_public, current_setting('app.current_user_id')::INT
    );

    RETURN jsonb_build_object('success', true, 'message', 'Product created');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to create product: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.update_product(
    p_id           INT,
    p_name         TEXT,
    p_calories     INT,
    p_portion_size NUMERIC,
    p_portion_unit TEXT,
    p_protein      NUMERIC,
    p_fat          NUMERIC,
    p_carbs        NUMERIC,
    p_is_public    BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    UPDATE nutrition.products
    SET name               = p_name,
        calories_per_portion = p_calories,
        portion_size       = p_portion_size,
        portion_unit       = p_portion_unit,
        protein            = p_protein,
        fat                = p_fat,
        carbs              = p_carbs,
        is_public          = p_is_public
    WHERE id = p_id
      AND created_by = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object('success', true, 'message', 'Product updated');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to update product: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.delete_product(
    p_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    DELETE FROM nutrition.products
    WHERE id = p_id
      AND created_by = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object('success', true, 'message', 'Product deleted');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to delete product: ' || SQLERRM);
END;
$$;

-- Админ может обновлять любой продукт
CREATE OR REPLACE FUNCTION nutrition.admin_update_product(
  p_id           INT,
  p_name         TEXT,
  p_calories     INT,
  p_portion_size NUMERIC,
  p_portion_unit TEXT,
  p_protein      NUMERIC,
  p_fat          NUMERIC,
  p_carbs        NUMERIC,
  p_is_public    BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
  IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  UPDATE nutrition.products
  SET name               = p_name,
      calories_per_portion = p_calories,
      portion_size       = p_portion_size,
      portion_unit       = p_portion_unit,
      protein            = p_protein,
      fat                = p_fat,
      carbs              = p_carbs,
      is_public          = p_is_public
  WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Product not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Product updated');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Failed to update product: ' || SQLERRM);
END;
$$;

-- Админ удаляет любой продукт
CREATE OR REPLACE FUNCTION nutrition.admin_delete_product(
    p_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
  IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  DELETE FROM nutrition.products WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Product not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Product deleted');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Failed to delete product: ' || SQLERRM);
END;
$$;

-- Экспорт всех продуктов (админ)
CREATE OR REPLACE FUNCTION nutrition.admin_export_products()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
  IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', (SELECT jsonb_agg(row_to_json(p)) FROM nutrition.products p)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Export products failed: ' || SQLERRM);
END;
$$;

-- Импорт продуктов (админ)
CREATE OR REPLACE FUNCTION nutrition.admin_import_products(p_products JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
  rec JSONB;
BEGIN
  IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  FOR rec IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    INSERT INTO nutrition.products(
      name,
      calories_per_portion,
      portion_size,
      portion_unit,
      protein,
      fat,
      carbs,
      is_public,
      created_by
    )
    VALUES (
      rec->>'name',
      COALESCE(NULLIF(rec->>'calories_per_portion','')::INT,
               NULLIF(rec->>'calories','')::INT),
      COALESCE(NULLIF(rec->>'portion_size','')::NUMERIC, 1),
      COALESCE(NULLIF(rec->>'portion_unit',''), 'g'),
      COALESCE(NULLIF(rec->>'protein','')::NUMERIC, 0),
      COALESCE(NULLIF(rec->>'fat','')::NUMERIC, 0),
      COALESCE(NULLIF(rec->>'carbs','')::NUMERIC, 0),
      COALESCE((rec->>'is_public')::BOOLEAN, true),
      current_setting('app.current_user_id')::INT
    )
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'message', 'Products imported');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Import products failed: ' || SQLERRM);
END;
$$;

-- Экспорт продуктов текущего пользователя (user)
CREATE OR REPLACE FUNCTION nutrition.user_export_products()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', true,
    'data', (
      SELECT jsonb_agg(row_to_json(p))
      FROM nutrition.products p
      WHERE p.created_by = current_setting('app.current_user_id')::INT
         OR p.is_public = TRUE
    )
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Export products failed: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- МЕНЮ ПОЛЬЗОВАТЕЛЯ (menu_items)
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.add_product_to_menu(
    p_product_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    INSERT INTO nutrition.menu_items(user_id, product_id)
    VALUES (current_setting('app.current_user_id')::INT, p_product_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object('success', true, 'message', 'Product added to menu');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to add product to menu: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.remove_product_from_menu(
    p_product_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    DELETE FROM nutrition.menu_items
    WHERE user_id   = current_setting('app.current_user_id')::INT
      AND product_id = p_product_id;

    RETURN jsonb_build_object('success', true, 'message', 'Product removed from menu');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to remove product from menu: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- ПОТРЕБЛЁННАЯ ЕДА (consumed_food + daily_menu/weekly_menu)
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.add_consumed_food(
    p_product_id   INT,
    p_quantity     NUMERIC,
    p_consumed_at  DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    v_user_id       INT;
    v_daily_menu_id INT;
BEGIN
    v_user_id := current_setting('app.current_user_id')::INT;
    v_daily_menu_id := nutrition.ensure_daily_menu(v_user_id, p_consumed_at);

    INSERT INTO nutrition.consumed_food(daily_menu_id, product_id, quantity)
    VALUES (v_daily_menu_id, p_product_id, p_quantity);

    RETURN jsonb_build_object('success', true, 'message', 'Consumed food added');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to add consumed food: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.remove_consumed_food(
    p_id INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    v_user_id INT;
BEGIN
    v_user_id := current_setting('app.current_user_id')::INT;

    DELETE FROM nutrition.consumed_food cf
    USING nutrition.daily_menu dm,
          nutrition.weekly_menu wm
    WHERE cf.id           = p_id
      AND cf.daily_menu_id = dm.id
      AND dm.weekly_menu_id = wm.id
      AND wm.user_id      = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Consumed food not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Consumed food removed');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to remove consumed food: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_daily_consumption(
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',         cf.id,
                    'productId',  cf.product_id,
                    'productName',p.name,
                    'quantity',   cf.quantity,
                    'calories',   p.calories_per_portion * cf.quantity
                )
            )
            FROM nutrition.consumed_food cf
            JOIN nutrition.daily_menu dm  ON dm.id = cf.daily_menu_id
            JOIN nutrition.weekly_menu wm ON wm.id = dm.weekly_menu_id
            JOIN nutrition.products p     ON p.id = cf.product_id
            WHERE wm.user_id   = current_setting('app.current_user_id')::INT
              AND dm.menu_date = p_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get daily consumption: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- МЕНЮ НА ДЕНЬ / НЕДЕЛЮ (generate/get/regenerate)
--------------------------------------------------
set role app_user;


CREATE OR REPLACE FUNCTION nutrition.generate_weekly_menu(
    p_week_start DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    i               INT;
    day_date        DATE;
    v_user_id       INT;
    v_daily_menu_id INT;
BEGIN
    v_user_id := current_setting('app.current_user_id')::INT;

    FOR i IN 0..6 LOOP
        day_date := p_week_start + i;
        v_daily_menu_id := nutrition.ensure_daily_menu(v_user_id, day_date);

        -- очищаем план/потребление на этот день
        DELETE FROM nutrition.consumed_food
        WHERE daily_menu_id = v_daily_menu_id;

        INSERT INTO nutrition.consumed_food(daily_menu_id, product_id, quantity)
        SELECT v_daily_menu_id, mi.product_id, 1
        FROM nutrition.menu_items mi
        WHERE mi.user_id = v_user_id
        ORDER BY random()
        LIMIT 5;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'message', 'Weekly menu generated');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to generate weekly menu: ' || SQLERRM);
END;
$$;



CREATE OR REPLACE FUNCTION nutrition.get_weekly_menu(
    p_week_start DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', dm.menu_date,
                    'products', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',                p.id,
                                'name',              p.name,
                                'caloriesPerPortion',p.calories_per_portion,
                                'portionSize',       p.portion_size,
                                'portionUnit',       p.portion_unit,
                                'quantity',          cf.quantity
                            )
                        )
                        FROM nutrition.consumed_food cf
                        JOIN nutrition.products p ON p.id = cf.product_id
                        WHERE cf.daily_menu_id = dm.id
                    )
                )
            )
            FROM nutrition.weekly_menu wm
            JOIN nutrition.daily_menu dm ON dm.weekly_menu_id = wm.id
            WHERE wm.user_id   = current_setting('app.current_user_id')::INT
              AND dm.menu_date BETWEEN p_week_start AND p_week_start + 6
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get weekly menu: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_daily_menu(
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',                p.id,
                    'name',              p.name,
                    'caloriesPerPortion',p.calories_per_portion,
                    'portionSize',       p.portion_size,
                    'portionUnit',       p.portion_unit,
                    'quantity',          cf.quantity
                )
            )
            FROM nutrition.weekly_menu wm
            JOIN nutrition.daily_menu dm ON dm.weekly_menu_id = wm.id
            JOIN nutrition.consumed_food cf ON cf.daily_menu_id = dm.id
            JOIN nutrition.products p ON p.id = cf.product_id
            WHERE wm.user_id   = current_setting('app.current_user_id')::INT
              AND dm.menu_date = p_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get daily menu: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.regenerate_day(
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    v_user_id       INT;
    v_daily_menu_id INT;
BEGIN
    v_user_id := current_setting('app.current_user_id')::INT;
    v_daily_menu_id := nutrition.ensure_daily_menu(v_user_id, p_date);

    DELETE FROM nutrition.consumed_food
    WHERE daily_menu_id = v_daily_menu_id;

    INSERT INTO nutrition.consumed_food(daily_menu_id, product_id, quantity)
    SELECT v_daily_menu_id, mi.product_id, 1
    FROM nutrition.menu_items mi
    WHERE mi.user_id = v_user_id
    ORDER BY random()
    LIMIT 5;

    RETURN jsonb_build_object('success', true, 'message', 'Daily menu regenerated');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to regenerate daily menu: ' || SQLERRM);
END;
$$;

--------------------------------------------------
-- ОТЧЁТЫ / ПРОГРЕСС
--------------------------------------------------

CREATE OR REPLACE FUNCTION nutrition.get_calorie_progress(
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    daily_total NUMERIC;
    daily_limit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(p.calories_per_portion * cf.quantity), 0)
    INTO daily_total
    FROM nutrition.consumed_food cf
    JOIN nutrition.daily_menu dm  ON dm.id = cf.daily_menu_id
    JOIN nutrition.weekly_menu wm ON wm.id = dm.weekly_menu_id
    JOIN nutrition.products p     ON p.id = cf.product_id
    WHERE wm.user_id   = current_setting('app.current_user_id')::INT
      AND dm.menu_date = p_date;

    SELECT daily_cal_limit INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'date',           p_date,
            'totalCalories',  daily_total,
            'dailyLimit',     daily_limit,
            'percentOfLimit', CASE WHEN daily_limit > 0 THEN round(daily_total*100/daily_limit,2) ELSE 0 END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get calorie progress: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_daily_report(
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    total_calories NUMERIC;
    daily_limit    NUMERIC;
BEGIN
    SELECT COALESCE(SUM(p.calories_per_portion * cf.quantity), 0)
    INTO total_calories
    FROM nutrition.consumed_food cf
    JOIN nutrition.daily_menu dm  ON dm.id = cf.daily_menu_id
    JOIN nutrition.weekly_menu wm ON wm.id = dm.weekly_menu_id
    JOIN nutrition.products p     ON p.id = cf.product_id
    WHERE wm.user_id   = current_setting('app.current_user_id')::INT
      AND dm.menu_date = p_date;

    SELECT daily_cal_limit INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'date',           p_date,
            'totalCalories',  total_calories,
            'dailyLimit',     daily_limit,
            'percentOfLimit', CASE WHEN daily_limit > 0 THEN round(total_calories*100/daily_limit,2) ELSE 0 END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get daily report: ' || SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_weekly_report(p_week_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    daily_limit NUMERIC;
BEGIN
    SELECT daily_cal_limit
    INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date',          t.menu_date,
                    'totalCalories', t.total_calories,
                    'dailyLimit',    daily_limit,
                    'percentOfLimit',
                        CASE WHEN daily_limit > 0
                             THEN round(t.total_calories * 100 / daily_limit, 2)
                             ELSE 0 END
                )
            )
            FROM (
                SELECT dm.menu_date,
                       COALESCE(SUM(p.calories_per_portion * cf.quantity), 0) AS total_calories
                FROM nutrition.weekly_menu wm
                JOIN nutrition.daily_menu dm
                  ON dm.weekly_menu_id = wm.id
                LEFT JOIN nutrition.consumed_food cf
                  ON cf.daily_menu_id = dm.id
                LEFT JOIN nutrition.products p
                  ON p.id = cf.product_id
                WHERE wm.user_id   = current_setting('app.current_user_id')::INT
                  AND dm.menu_date BETWEEN p_week_start AND p_week_start + 6
                GROUP BY dm.menu_date
                ORDER BY dm.menu_date
            ) AS t
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get weekly report: ' || SQLERRM
    );
END;
$$;

CREATE OR REPLACE FUNCTION nutrition.get_weight_report(
    p_week_start DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    start_weight NUMERIC;
    end_weight   NUMERIC;
BEGIN
    SELECT weight INTO start_weight
    FROM nutrition.weight_history
    WHERE user_id    = current_setting('app.current_user_id')::INT
      AND record_date = p_week_start
    LIMIT 1;

    SELECT weight INTO end_weight
    FROM nutrition.weight_history
    WHERE user_id    = current_setting('app.current_user_id')::INT
      AND record_date <= p_week_start + 6
    ORDER BY record_date DESC
    LIMIT 1;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'weekStart',   p_week_start,
            'startWeight', start_weight,
            'endWeight',   end_weight,
            'weightChange', CASE
                              WHEN start_weight IS NOT NULL
                               AND end_weight IS NOT NULL
                              THEN round(end_weight - start_weight,2)
                              ELSE NULL
                            END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Failed to get weight report: ' || SQLERRM);
END;
$$;