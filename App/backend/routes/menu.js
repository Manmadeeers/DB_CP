import express from 'express';
import { callDbFunction } from '../db.js';
import { withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// Добавить продукт в меню пользователя
router.post('/add', async (req, res) => {
  const { product_id } = req.body;
  try {
    const result = await callDbFunction('add_product_to_menu', [product_id], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Удалить продукт из меню пользователя
router.post('/remove', async (req, res) => {
  const { product_id } = req.body;
  try {
    const result = await callDbFunction('remove_product_from_menu', [product_id], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Сгенерировать меню на неделю
router.post('/generate-week', async (req, res) => {
  const { week_start } = req.body; // формат YYYY-MM-DD
  try {
    const result = await callDbFunction('generate_weekly_menu', [week_start], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Получить меню на неделю
router.get('/week', async (req, res) => {
  const { week_start } = req.query;
  try {
    const result = await callDbFunction('get_weekly_menu', [week_start], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Получить меню на день
router.get('/day', async (req, res) => {
  const { date } = req.query;
  try {
    const result = await callDbFunction('get_daily_menu', [date], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Перегенерировать меню на день
router.post('/regenerate-day', async (req, res) => {
  const { date } = req.body;
  try {
    const result = await callDbFunction('regenerate_day', [date], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;
