
-- импорт продуктов из JSON (админ), принимает JSON-массив объектов
CREATE OR REPLACE FUNCTION nutrition.admin_import_products(p_products JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = nutrition, pg_temp
AS $$
DECLARE rec JSONB;
BEGIN
  IF current_setting('app.current_user_role', true) <> 'app_admin' THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  FOR rec IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    INSERT INTO nutrition.products(name, calories_per_portion, portion_size, portion_unit,
                                   protein, fat, carbs, is_public, created_by)
    VALUES (
      rec->>'name',
      COALESCE((rec->>'calories_per_portion')::INT, rec->>'calories')::INT,
      (rec->>'portion_size')::NUMERIC,
      rec->>'portion_unit',
      (rec->>'protein')::NUMERIC,
      (rec->>'fat')::NUMERIC,
      (rec->>'carbs')::NUMERIC,
      COALESCE((rec->>'is_public')::BOOLEAN, true),
      current_setting('app.current_user_id')::INT
    )
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'message', 'Products imported');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Import products failed: ' || SQLERRM);
END;
$$;

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
    'data', (SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'username', username, 'role', role,
      'dailyCalorieLimit', daily_cal_limit, 'weeklyCalorieLimit', weekly_cal_limit,
      'createdAt', create_at)) FROM nutrition.users)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'Export users failed: ' || SQLERRM);
END;
$$;

-- экспорт всех продуктов (админ)
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



