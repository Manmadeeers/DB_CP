
CREATE ROLE app_admin
	LOGIN
	PASSWORD 'Strong_admin_pass123!';

CREATE ROLE app_user
	LOGIN 
	PASSWORD 'Strong_user_pass123!';

ALTER TABLE nutrition.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.weekly_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.daily_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.consumed_food ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.weight_history ENABLE ROW LEVEL SECURITY;


--nutrition.users policies
CREATE POLICY user_own_profile_select
ON nutrition.users
FOR SELECT
USING (id = current_setting('app.current_user_id')::INT);

CREATE POLICY user_own_profile_update
ON nutrition.users
FOR SELECT
USING (id = current_setting('app.current_user_id')::INT);

CREATE POLICY admin_all_users
ON nutrition.users
FOR ALL
USING (current_user='app_admin');
--end of nutrition.users policies

--nutrition.products policies

CREATE POLICY user_products_select
ON nutrition.products
FOR SELECT
USING (
	is_public=TRUE 
	OR created_by = current_setting('app.current_user_id')::INT
);

CREATE POLICY products_insert_own
ON nutrition.products
FOR INSERT
WITH CHECK(
	created_by = current_setting('app.current_user_id')::INT
);

CREATE POLICY products_update_own
ON nutrition.products
FOR UPDATE
USING(
	created_by = current_setting('app.current_user_id')::INT
);

CREATE POLICY products_delete_own
ON nutrition.products
FOR DELETE
USING(
	created_by = current_setting('app.current_user_id')::INT
);

CREATE POLICY admin_products
ON nutrition.products
FOR ALL
USING (current_user = 'app_admin');
--end of nutrition.products policies

--nutrition.menu_items policies

CREATE POLICY user_menu_items_all
ON nutrition.menu_items
FOR ALL
USING(
	user_id = current_setting('app.current_user_id')::INT
)
WITH CHECK(
	user_id = current_setting('app.current_user_id')::INT
);
--end of nutrition.menu_items policies

--nutrition.weekly_menu policies

CREATE POLICY user_weekly_menu_all
ON nutrition.weekly_menu
FOR ALL
USING(
	user_id = current_setting('app.current_user_id')::INT
)
WITH CHECK(
	user_id = current_setting('app.current_user_id')::INT
);
--end of nutrition.weekly_menu policies


--nutrition.daily_menu policies
CREATE POLICY user_daily_menu_all
ON nutrition.daily_menu
FOR ALL
USING(
	weekly_menu_id IN(
		SELECT id
		FROM nutrition.weekly_menu
		WHERE user_id = current_setting('app.current_user_id')::INT
	)
);
--end of nutrition.daily_menu policies



--nutrition.consumed_food policies
CREATE POLICY user_consumed_food_all
ON nutrition.consumed_food
FOR ALL
USING(
	daily_menu_id IN(
		SELECT dm.id
		FROM nutrition.daily_menu dm
		JOIN mutrition.weekly_menu wm on wm.id dm.weekly_menu_id
		WHERE wm.user_id = current_setting('app.current_user_id')::INT
	)
);
--end of nutrition.consumed_food policies



--weight_history policies

CREATE POLICY user_weight_history_all
ON nutrition.weight_history
FOR ALL
USING (
    user_id = current_setting('app.current_user_id')::INT
)
WITH CHECK(
	user_id = current_setting('app.current_user_id')::INT
);


REVOKE ALL ON ALL TABLES IN SCHEMA nutrition FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA nutrition FROM app_user;

/*SET ROLE app_user;
SET app.current_user_id = '1';
SELECT * from nutrition.products;*/

	