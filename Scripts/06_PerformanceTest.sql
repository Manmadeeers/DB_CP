SELECT schema_name FROM information_schema.schemata;
select current_schema();
select current_user;
set role to app_admin;
set role to postgres;
DELETE FROM nutrition.products;
set search_path to nutrition;

SELECT nutrition.admin_create_admin('performance_admin','pHash');

CREATE OR REPLACE FUNCTION nutrition.generate_test_products(
    p_count INT DEFAULT 100000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE
    i INT;
    product_name TEXT;
    base_names TEXT[] := ARRAY[
        'Курица', 'Говядина', 'Свинина', 'Рыба', 'Лосось',
        'Тунец', 'Рис', 'Гречка', 'Овсянка', 'Макароны',
        'Картофель', 'Брокколи', 'Сыр', 'Творог', 'Яйца',
        'Молоко', 'Йогурт', 'Хлеб', 'Яблоко', 'Банан'
    ];
    modifiers TEXT[] := ARRAY[
        'отварной', 'жареный', 'запечённый', 'на пару',
        'обезжиренный', 'классический', 'домашний'
    ];
    portion_size NUMERIC;
    calories INT;
    protein NUMERIC;
    fat NUMERIC;
    carbs NUMERIC;
BEGIN
    FOR i IN 1..p_count LOOP
        product_name :=
            base_names[1 + floor(random() * array_length(base_names, 1))] || ' ' ||
            modifiers[1 + floor(random() * array_length(modifiers, 1))] || ' #' || i;

        portion_size := round((30 + random() * 270)::numeric, 1);
        calories := (50 + random() * 550)::INT;

        protein := round((calories * (0.1 + random() * 0.4) / 4)::numeric, 1);
        fat     := round((calories * (0.1 + random() * 0.4) / 9)::numeric, 1);
        carbs   := round((calories * (0.2 + random() * 0.6) / 4)::numeric, 1);

        INSERT INTO products (
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
            product_name,
            calories,
            portion_size,
            'g',
            protein,
            fat,
            carbs,
            (random() > 0.3),
            current_setting('app.current_user_id')::INT
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('%s products generated successfully', p_count)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to generate test products: ' || SQLERRM
    );
END;
$$;
SELECT current_setting('app.current_user_id', true);
SELECT nutrition.admin_get_all_users();

select * from nutrition.users;

SET app.current_user_id = 1;

SELECT nutrition.generate_test_products(200);
SELECT nutrition.get_available_products();

	EXPLAIN ANALYZE
	SELECT nutrition.get_product_by_name('йогурт');


CREATE INDEX idx_product_name on nutrition.products(name);
