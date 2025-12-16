CREATE OR REPLACE FUNCTION nutrition.user_logout()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    -- Обнуляем переменные сессии
    PERFORM set_config('app.current_user_id', NULL, false);
    PERFORM set_config('app.current_user_role', NULL, false);

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Logout successful'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Logout failed: ' || SQLERRM
    );
END;
$$;



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
    user_id INT;
    user_role TEXT;
BEGIN
    -- Получаем хэш пароля и данные пользователя
    SELECT id, password_hash, role INTO user_id, stored_hash, user_role
    FROM nutrition.users
    WHERE username = p_username;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid username or password'
        );
    END IF;

    -- Проверка пароля (используем crypt)
    IF crypt(p_password, stored_hash) <> stored_hash THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid username or password'
        );
    END IF;

    -- Устанавливаем переменные сессии
    PERFORM set_config('app.current_user_id', user_id::TEXT, false);
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
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Login failed: ' || SQLERRM
    );
END;
$$;




--GET all users

CREATE OR REPLACE FUNCTION nutrition.admin_get_all_users()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
BEGIN
    -- Проверка, что текущий пользователь — админ
    IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
        RAISE EXCEPTION 'Access denied: admin only';
    END IF;

    -- Возвращаем JSON с массивом пользователей
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(user_row)
            FROM (
                SELECT jsonb_build_object(
                    'id', id,
                    'username', username,
                    'role', role,
                    'dailyCalorieLimit', daily_cal_limit,
                    'weeklyCalorieLimit', weekly_cal_limit,
                    'createdAt', create_at
                ) AS user_row
                FROM nutrition.users
                ORDER BY id
            ) AS sub
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to fetch users: ' || SQLERRM
    );
END;
$$;


--CREATE admin
CREATE OR REPLACE FUNCTION nutrition.admin_create_admin(
    p_username TEXT,
    p_password_hash TEXT,
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

    INSERT INTO nutrition.users (
        username,
        password_hash,
        daily_cal_limit,
        weekly_cal_limit,
        role
    )
    VALUES (
        p_username,
        p_password_hash,
        p_daily_cal_limit,
        p_weekly_cal_limit,
        'app_admin'
    )
    RETURNING id INTO new_admin_id;

    RETURN jsonb_build_object(
        'success', true,
        'adminId', new_admin_id,
        'message', 'Administrator created'
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username already exists'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Failed to create administrator: ' || SQLERRM
        );
END;
$$;

--DELETE admin
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
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Administrator not found'
        );
    END IF;

    SELECT COUNT(*) INTO admin_count
    FROM nutrition.users
    WHERE role = 'app_admin';

    IF admin_count <= 1 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cannot delete the last administrator'
        );
    END IF;

    DELETE FROM nutrition.users WHERE id = p_admin_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Administrator deleted'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to delete administrator: ' || SQLERRM
    );
END;
$$;


--CREATE user
CREATE OR REPLACE FUNCTION nutrition.admin_create_user(
    p_username TEXT,
    p_password_hash TEXT,
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

    INSERT INTO nutrition.users (
        username,
        password_hash,
        daily_cal_limit,
        weekly_cal_limit,
        role
    )
    VALUES (
        p_username,
        p_password_hash,
        p_daily_cal_limit,
        p_weekly_cal_limit,
        'app_user'
    )
    RETURNING id INTO new_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'userId', new_user_id,
        'message', 'User created'
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username already exists'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Failed to create user: ' || SQLERRM
        );
END;
$$;


--UPDATE user
CREATE OR REPLACE FUNCTION nutrition.admin_update_user(
    p_user_id INT,
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
    SET daily_cal_limit = p_daily_cal_limit,
        weekly_cal_limit = p_weekly_cal_limit
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User updated'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to update user: ' || SQLERRM
    );
END;
$$;



--DELETE user
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
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    IF user_role = 'app_admin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Use admin_delete_admin to delete administrators'
        );
    END IF;

    DELETE FROM nutrition.users WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User deleted'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to delete user: ' || SQLERRM
    );
END;
$$;




--GET /api/profile
CREATE OR REPLACE FUNCTION nutrition.get_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'success', true,
            'data', jsonb_build_object(
                'id', u.id,
                'username', u.username,
                'dailyCalorieLimit', u.daily_cal_limit,
                'weeklyCalorieLimit', u.weekly_cal_limit
            )
        )
        FROM nutrition.users u
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get user info: ' || SQLERRM
    );
END;
$$;


--PUT /api/profile
CREATE OR REPLACE FUNCTION nutrition.update_my_profile(
    p_daily_cal_limit INT,
    p_weekly_cal_limit INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE nutrition.users
    SET daily_cal_limit = p_daily_cal_limit,
        weekly_cal_limit = p_weekly_cal_limit
    WHERE id = current_setting('app.current_user_id')::INT;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Profile updated'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to update user data: ' || SQLERRM
    );
END;
$$;


--GET /api/profile/weight

CREATE OR REPLACE FUNCTION nutrition.get_weight_history()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', record_date,
                    'weight', weight
                )
            )
            FROM nutrition.weight_history
            WHERE user_id = current_setting('app.current_user_id')::int
            ORDER BY record_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get weight history: ' || SQLERRM
    );
END;
$$;


--POST /api/profile/weight
CREATE OR REPLACE FUNCTION nutrition.add_weight_record(
    p_date DATE,
    p_weight NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO nutrition.weight_history(user_id, record_date, weight)
    VALUES (current_setting('app.current_user_id')::int, p_date, p_weight)
    ON CONFLICT (user_id, record_date)
    DO UPDATE SET weight = EXCLUDED.weight;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Weight record saved'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to add weight record: ' || SQLERRM
    );
END;
$$;



--GET /api/products
CREATE OR REPLACE FUNCTION nutrition.get_available_products()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'name', p.name,
                    'caloriesPerPortion', p.calories_per_portion,
                    'portionSize', p.portion_size,
                    'portionUnit', p.portion_unit,
                    'protein', p.protein,
                    'fat', p.fat,
                    'carbs', p.carbs,
                    'isPublic', p.is_public
                )
            )
            FROM nutrition.products p
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get products: ' || SQLERRM
    );
END;
$$;

--GET product by name
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
                    'id', p.id,
                    'name', p.name,
                    'caloriesPerPortion', p.calories_per_portion,
                    'portionSize', p.portion_size,
                    'portionUnit', p.portion_unit,
                    'protein', p.protein,
                    'fat', p.fat,
                    'carbs', p.carbs,
                    'isPublic', p.is_public,
                    'createdBy', p.created_by
                )
            )
            FROM nutrition.products p
            WHERE p.name ILIKE '%' || p_name || '%'
              AND (
                    p.is_public = TRUE
                    OR p.created_by = current_setting('app.current_user_id')::INT
                  )
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to fetch product by name: ' || SQLERRM
    );
END;
$$;



--POST /api/products
CREATE OR REPLACE FUNCTION nutrition.create_product(
    p_name TEXT,
    p_calories INT,
    p_portion_size NUMERIC,
    p_portion_unit TEXT,
    p_protein NUMERIC,
    p_fat NUMERIC,
    p_carbs NUMERIC,
    p_is_public BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO nutrition.products(
        name, calories_per_portion, portion_size, portion_unit,
        protein, fat, carbs, is_public, created_by
    ) VALUES (
        p_name, p_calories, p_portion_size, p_portion_unit,
        p_protein, p_fat, p_carbs, p_is_public, current_setting('app.current_user_id')::int
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Product created'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to create product: ' || SQLERRM
    );
END;
$$;

--PUT /api/products/:id

CREATE OR REPLACE FUNCTION nutrition.update_product(
    p_id INT,
    p_name TEXT,
    p_calories INT,
    p_portion_size NUMERIC,
    p_portion_unit TEXT,
    p_protein NUMERIC,
    p_fat NUMERIC,
    p_carbs NUMERIC,
    p_is_public BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE nutrition.products
    SET name = p_name,
        calories_per_portion = p_calories,
        portion_size = p_portion_size,
        portion_unit = p_portion_unit,
        protein = p_protein,
        fat = p_fat,
        carbs = p_carbs,
        is_public = p_is_public
    WHERE id = p_id
      AND created_by = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Product updated'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to update product: ' || SQLERRM
    );
END;
$$;


--DELETE /api/products/:id

CREATE OR REPLACE FUNCTION nutrition.delete_product(p_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM nutrition.products
    WHERE id = p_id
      AND created_by = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Product deleted'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to delete product: ' || SQLERRM
    );
END;
$$;


--Add product to user's menu

CREATE OR REPLACE FUNCTION nutrition.add_product_to_menu(p_product_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO nutrition.menu_items(user_id, product_id)
    VALUES (current_setting('app.current_user_id')::int, p_product_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Product added to menu'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to add product to menu: ' || SQLERRM
    );
END;
$$;

--remove product from user's menu
CREATE OR REPLACE FUNCTION nutrition.remove_product_from_menu(p_product_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM nutrition.menu_items
    WHERE user_id = current_setting('app.current_user_id')::int
      AND product_id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Product removed from menu'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to remove product from menu: ' || SQLERRM
    );
END;
$$;

--POST /api/consumed-food

CREATE OR REPLACE FUNCTION nutrition.add_consumed_food(
    p_product_id INT,
    p_quantity NUMERIC,
    p_consumed_at DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    calories NUMERIC;
BEGIN
    SELECT calories_per_portion * p_quantity
    INTO calories
    FROM nutrition.products
    WHERE id = p_product_id;

    INSERT INTO nutrition.consumed_food(user_id, product_id, quantity, consumed_at, calories)
    VALUES (
        current_setting('app.current_user_id')::int,
        p_product_id,
        p_quantity,
        p_consumed_at,
        calories
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Consumed food added',
        'caloriesAdded', calories
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to add consumed food: ' || SQLERRM
    );
END;
$$;


--DELETE /api/consumed-foor/:id
CREATE OR REPLACE FUNCTION nutrition.remove_consumed_food(p_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM nutrition.consumed_food
    WHERE id = p_id
      AND user_id = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Consumed food removed'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to remove consumed food: ' || SQLERRM
    );
END;
$$;


--GET /api/consumed-food?date

CREATE OR REPLACE FUNCTION nutrition.get_daily_consumption(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', cf.id,
                    'productId', cf.product_id,
                    'productName', p.name,
                    'quantity', cf.quantity,
                    'calories', cf.calories
                )
            )
            FROM nutrition.consumed_food cf
            JOIN nutrition.products p ON p.id = cf.product_id
            WHERE cf.user_id = current_setting('app.current_user_id')::int
              AND cf.consumed_at = p_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get daily consumption: ' || SQLERRM
    );
END;
$$;

--GET /api/calories/progress?date

CREATE OR REPLACE FUNCTION nutrition.get_calorie_progress(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    daily_total NUMERIC;
    daily_limit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(calories),0)
    INTO daily_total
    FROM nutrition.consumed_food
    WHERE user_id = current_setting('app.current_user_id')::int
      AND consumed_at = p_date;

    SELECT daily_cal_limit
    INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'date', p_date,
            'totalCalories', daily_total,
            'dailyLimit', daily_limit,
            'percentOfLimit', CASE WHEN daily_limit > 0 THEN round(daily_total*100/daily_limit,2) ELSE 0 END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get calorie progress: ' || SQLERRM
    );
END;
$$;

--POST /api/menu/generate-week
CREATE OR REPLACE FUNCTION nutrition.generate_weekly_menu(p_week_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    i INT;
    day_date DATE;
    product RECORD;
BEGIN
    FOR i IN 0..6 LOOP
        day_date := p_week_start + i;
		
        INSERT INTO nutrition.weekly_menu(user_id, menu_date, product_id)
        SELECT current_setting('app.current_user_id')::int, day_date, p.id
        FROM nutrition.menu_items mi
        JOIN nutrition.products p ON p.id = mi.product_id
        ORDER BY random()
        LIMIT 5; --daily products limit
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Weekly menu generated'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to generate weekly menu: ' || SQLERRM
    );
END;
$$;

--GET/api/menu/week?weekstart=date
CREATE OR REPLACE FUNCTION nutrition.get_weekly_menu(p_week_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', wm.menu_date,
                    'products', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', p.id,
                                'name', p.name,
                                'caloriesPerPortion', p.calories_per_portion,
                                'portionSize', p.portion_size,
                                'portionUnit', p.portion_unit
                            )
                        )
                        FROM nutrition.products p
                        JOIN nutrition.weekly_menu w ON w.product_id = p.id
                        WHERE w.user_id = wm.user_id AND w.menu_date = wm.menu_date
                    )
                )
            )
            FROM nutrition.weekly_menu wm
            WHERE wm.user_id = current_setting('app.current_user_id')::int
              AND wm.menu_date BETWEEN p_week_start AND p_week_start + 6
            ORDER BY wm.menu_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get weekly menu: ' || SQLERRM
    );
END;
$$;

--GET /api/menu/day?date

CREATE OR REPLACE FUNCTION nutrition.get_daily_menu(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'name', p.name,
                    'caloriesPerPortion', p.calories_per_portion,
                    'portionSize', p.portion_size,
                    'portionUnit', p.portion_unit
                )
            )
            FROM nutrition.products p
            JOIN nutrition.weekly_menu w ON w.product_id = p.id
            WHERE w.user_id = current_setting('app.current_user_id')::int
              AND w.menu_date = p_date
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get daily menu: ' || SQLERRM
    );
END;
$$;

--POST /api/menu/regenerate-day

CREATE OR REPLACE FUNCTION nutrition.regenerate_day(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Удаляем старое меню на этот день
    DELETE FROM nutrition.weekly_menu
    WHERE user_id = current_setting('app.current_user_id')::int
      AND menu_date = p_date;

    -- Вставляем новые продукты (пример: 5 случайных продуктов из меню пользователя)
    INSERT INTO nutrition.weekly_menu(user_id, menu_date, product_id)
    SELECT current_setting('app.current_user_id')::int, p_date, p.id
    FROM nutrition.menu_items mi
    JOIN nutrition.products p ON p.id = mi.product_id
    ORDER BY random()
    LIMIT 5;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Daily menu regenerated'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to regenerate daily menu: ' || SQLERRM
    );
END;
$$;


--GET /api/reports/daily?date

CREATE OR REPLACE FUNCTION nutrition.get_daily_report(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_calories NUMERIC;
    daily_limit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(calories),0)
    INTO total_calories
    FROM nutrition.consumed_food
    WHERE user_id = current_setting('app.current_user_id')::int
      AND consumed_at = p_date;

    SELECT daily_cal_limit
    INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'date', p_date,
            'totalCalories', total_calories,
            'dailyLimit', daily_limit,
            'percentOfLimit', CASE WHEN daily_limit > 0 THEN round(total_calories*100/daily_limit,2) ELSE 0 END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get daily report: ' || SQLERRM
    );
END;
$$;

--GET /api/reports/weekly?weekstart=date

CREATE OR REPLACE FUNCTION nutrition.get_weekly_report(p_week_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    daily RECORD;
    daily_limit NUMERIC;
BEGIN
    SELECT daily_cal_limit
    INTO daily_limit
    FROM nutrition.users
    WHERE id = current_setting('app.current_user_id')::int;

    RETURN jsonb_build_object(
        'success', true,
        'data', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', cf.consumed_at,
                    'totalCalories', SUM(cf.calories),
                    'dailyLimit', daily_limit,
                    'percentOfLimit', CASE WHEN daily_limit > 0 THEN round(SUM(cf.calories)*100/daily_limit,2) ELSE 0 END
                )
            )
            FROM nutrition.consumed_food cf
            WHERE cf.user_id = current_setting('app.current_user_id')::int
              AND cf.consumed_at BETWEEN p_week_start AND p_week_start + 6
            GROUP BY cf.consumed_at
            ORDER BY cf.consumed_at
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get weekly report: ' || SQLERRM
    );
END;
$$;


--GET /api/reports/weight-progress?weekStart=date

CREATE OR REPLACE FUNCTION nutrition.get_weight_report(p_week_start DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    start_weight NUMERIC;
    end_weight NUMERIC;
BEGIN
    SELECT weight INTO start_weight
    FROM nutrition.weight_history
    WHERE user_id = current_setting('app.current_user_id')::int
      AND record_date = p_week_start
    LIMIT 1;

    SELECT weight INTO end_weight
    FROM nutrition.weight_history
    WHERE user_id = current_setting('app.current_user_id')::int
      AND record_date <= p_week_start + 6
    ORDER BY record_date DESC
    LIMIT 1;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'weekStart', p_week_start,
            'startWeight', start_weight,
            'endWeight', end_weight,
            'weightChange', CASE WHEN start_weight IS NOT NULL AND end_weight IS NOT NULL THEN round(end_weight - start_weight,2) ELSE NULL END
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get weight report: ' || SQLERRM
    );
END;
$$;





