import pkg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const { Pool } = pkg;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

/**
 * Вызывает функцию из схемы nutrition и, при необходимости,
 * прокидывает контекст пользователя в локальные настройки соединения.
 */
export async function callDbFunction(funcName, params = [], context = {}) {
  const client = await pool.connect();
  const placeholders = params.map((_, i) => `$${i + 1}`).join(', ');
  const query = `SELECT nutrition.${funcName}(${placeholders});`;

  try {
    await client.query('BEGIN');

    if (context.userId) {
      await client.query("SELECT set_config('app.current_user_id', $1, false)", [
        String(context.userId),
      ]);
    }
    if (context.role) {
      await client.query("SELECT set_config('app.current_user_role', $1, false)", [
        String(context.role),
      ]);
    }

    const result = await client.query(query, params);
    await client.query('COMMIT');
    return result.rows[0][funcName]; // возвращаем JSONB
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export default pool;
