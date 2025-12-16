GRANT USAGE ON SCHEMA nutrition TO app_user, app_admin;
REVOKE ALL ON nutrition.users FROM app_user, app_admin;
REVOKE ALL ON nutrition.products FROM app_user, app_admin;
REVOKE ALL ON nutrition.menu_items FROM app_user, app_admin;
REVOKE ALL ON nutrition.weight_history FROM app_user, app_admin;

GRANT EXECUTE ON FUNCTION
    nutrition.get_my_profile(),
    nutrition.update_my_profile(INT, INT),
    nutrition.get_weight_history(),
    nutrition.add_weight_record(DATE, NUMERIC),
    nutrition.get_available_products(),
    nutrition.create_product(TEXT, INT, NUMERIC, TEXT, NUMERIC, NUMERIC, NUMERIC, BOOLEAN),
    nutrition.update_product(INT, TEXT, INT, NUMERIC, TEXT, NUMERIC, NUMERIC, NUMERIC, BOOLEAN),
    nutrition.delete_product(INT),
    nutrition.add_product_to_menu(INT),
    nutrition.remove_product_from_menu(INT)
TO app_user;

GRANT EXECUTE ON FUNCTION
    nutrition.admin_create_user(TEXT, TEXT, INT, INT),
    nutrition.admin_update_user(INT, INT, INT),
    nutrition.admin_delete_user(INT),
    nutrition.admin_create_admin(TEXT, TEXT, INT, INT),
    nutrition.admin_delete_admin(INT)
TO app_admin;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA nutrition TO app_user, app_admin;

REVOKE UPDATE (role, password_hash)
ON nutrition.users
FROM PUBLIC, app_user, app_admin;