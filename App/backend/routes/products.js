import express from 'express';
import { callDbFunction } from '../db.js';
import { requireRole, withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// Получить все продукты (публичные + свои)
router.get('/', async (req, res) => {
  try {
    const result = await callDbFunction('get_available_products', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Получить продукт по имени
router.get('/search', async (req, res) => {
  const { name } = req.query;
  try {
    const result = await callDbFunction('get_product_by_name', [name], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Экспорт продуктов текущего пользователя (название функции содержит "user")
router.get('/export/mine', async (req, res) => {
  try {
    const result = await callDbFunction('user_export_products', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Экспорт всех продуктов (только админ)
router.get('/export/all', requireRole('app_admin'), async (req, res) => {
  try {
    const result = await callDbFunction('admin_export_products', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Импорт продуктов из JSON (только админ)
router.post('/import', requireRole('app_admin'), async (req, res) => {
  const { products } = req.body;
  try {
    const result = await callDbFunction('admin_import_products', [products], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Создать продукт (публичный или персональный)
router.post('/', async (req, res) => {
  const { name, calories, portion_size, portion_unit, protein, fat, carbs, is_public } = req.body;
  try {
    const result = await callDbFunction(
      'create_product',
      [name, calories, portion_size, portion_unit, protein, fat, carbs, is_public],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Обновить продукт (создатель) или админская версия
router.put('/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { name, calories, portion_size, portion_unit, protein, fat, carbs, is_public } = req.body;
  const fn = req.header('x-user-role') === 'app_admin' ? 'admin_update_product' : 'update_product';
  try {
    const result = await callDbFunction(
      fn,
      [id, name, calories, portion_size, portion_unit, protein, fat, carbs, is_public],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Удалить продукт (создатель) или админская версия
router.delete('/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const fn = req.header('x-user-role') === 'app_admin' ? 'admin_delete_product' : 'delete_product';
  try {
    const result = await callDbFunction(fn, [id], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;
