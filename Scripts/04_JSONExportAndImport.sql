--GET /api/user/export

CREATE OR REPLACE FUNCTION nutrition.export_user_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'profile', (
                SELECT jsonb_build_object(
                    'username', u.username,
                    'dailyCalorieLimit', u.daily_cal_limit,
                    'weeklyCalorieLimit', u.weekly_cal_limit
                )
                FROM nutrition.users u
                WHERE u.id = current_setting('app.current_user_id')::int
            ),
            'weightHistory', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'date', record_date,
                        'weight', weight
                    )
                )
                FROM nutrition.weight_history
                WHERE user_id = current_setting('app.current_user_id')::int
                ORDER BY record_date
            ),
            'menuItems', (
                SELECT jsonb_agg(product_id)
                FROM nutrition.menu_items
                WHERE user_id = current_setting('app.current_user_id')::int
            ),
            'consumedFood', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'productId', product_id,
                        'quantity', quantity,
                        'consumedAt', consumed_at,
                        'calories', calories
                    )
                )
                FROM nutrition.consumed_food
                WHERE user_id = current_setting('app.current_user_id')::int
                ORDER BY consumed_at
            )
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to export user data: ' || SQLERRM
    );
END;
$$;

--POST /api/user/import

CREATE OR REPLACE FUNCTION nutrition.import_user_data(p_json JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Обновляем профиль
    UPDATE nutrition.users
    SET daily_cal_limit = p_json->'profile'->>'dailyCalorieLimit',
        weekly_cal_limit = p_json->'profile'->>'weeklyCalorieLimit'
    WHERE id = current_setting('app.current_user_id')::int;

    -- Импортируем историю веса
    DELETE FROM nutrition.weight_history
    WHERE user_id = current_setting('app.current_user_id')::int;

    INSERT INTO nutrition.weight_history(user_id, record_date, weight)
    SELECT current_setting('app.current_user_id')::int,
           (item->>'date')::DATE,
           (item->>'weight')::NUMERIC
    FROM jsonb_array_elements(p_json->'weightHistory') AS item;

    -- Импортируем меню
    DELETE FROM nutrition.menu_items
    WHERE user_id = current_setting('app.current_user_id')::int;

    INSERT INTO nutrition.menu_items(user_id, product_id)
    SELECT current_setting('app.current_user_id')::int, value::INT
    FROM jsonb_array_elements_text(p_json->'menuItems');

    -- Импортируем потреблённую еду
    DELETE FROM nutrition.consumed_food
    WHERE user_id = current_setting('app.current_user_id')::int;

    INSERT INTO nutrition.consumed_food(user_id, product_id, quantity, consumed_at, calories)
    SELECT current_setting('app.current_user_id')::int,
           (item->>'productId')::INT,
           (item->>'quantity')::NUMERIC,
           (item->>'consumedAt')::DATE,
           (item->>'calories')::NUMERIC
    FROM jsonb_array_elements(p_json->'consumedFood') AS item;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User data imported successfully'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to import user data: ' || SQLERRM
    );
END;
$$;

--GET /api/products/export
CREATE OR REPLACE FUNCTION nutrition.export_products()
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
        'error', 'Failed to export products: ' || SQLERRM
    );
END;
$$;


--POST /api/products/import

CREATE OR REPLACE FUNCTION nutrition.import_products(p_json JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO nutrition.products(
        name, calories_per_portion, portion_size, portion_unit,
        protein, fat, carbs, is_public, created_by
    )
    SELECT 
        item->>'name',
        (item->>'caloriesPerPortion')::INT,
        (item->>'portionSize')::NUMERIC,
        item->>'portionUnit',
        (item->>'protein')::NUMERIC,
        (item->>'fat')::NUMERIC,
        (item->>'carbs')::NUMERIC,
        (item->>'isPublic')::BOOLEAN,
        current_setting('app.current_user_id')::INT
    FROM jsonb_array_elements(p_json->'products') AS item;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Products imported successfully'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to import products: ' || SQLERRM
    );
END;
$$;




