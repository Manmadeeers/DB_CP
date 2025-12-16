import express from 'express';
import { callDbFunction } from '../db.js';
import { requireRole, withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext, requireRole('app_admin'));

// Получить всех пользователей (для админа)
router.get('/', async (req, res) => {
  try {
    const result = await callDbFunction('admin_get_all_users', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Экспорт всех пользователей в JSON
router.get('/export', async (req, res) => {
  try {
    const result = await callDbFunction('admin_export_users', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Создать пользователя (админ)
router.post('/', async (req, res) => {
  const { username, password_hash, daily_cal_limit, weekly_cal_limit } = req.body;
  try {
    const result = await callDbFunction(
      'admin_create_user',
      [username, password_hash, daily_cal_limit, weekly_cal_limit],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Создать админа
router.post('/admins', async (req, res) => {
  const { username, password_hash, daily_cal_limit = 2500, weekly_cal_limit = 17500 } = req.body;
  try {
    const result = await callDbFunction(
      'admin_create_admin',
      [username, password_hash, daily_cal_limit, weekly_cal_limit],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Обновить пользователя
router.put('/:id', async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  const { daily_cal_limit, weekly_cal_limit } = req.body;
  try {
    const result = await callDbFunction(
      'admin_update_user',
      [userId, daily_cal_limit, weekly_cal_limit],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Удалить пользователя
router.delete('/:id', async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  try {
    const result = await callDbFunction('admin_delete_user', [userId], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Удалить администратора
router.delete('/admins/:id', async (req, res) => {
  const adminId = parseInt(req.params.id, 10);
  try {
    const result = await callDbFunction('admin_delete_admin', [adminId], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;
