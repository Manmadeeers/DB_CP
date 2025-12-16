import express from 'express';
import { callDbFunction } from '../db.js';
import { withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// Отчет по дням
router.get('/daily', async (req, res) => {
  const { date } = req.query;
  try {
    const result = await callDbFunction('get_daily_report', [date], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Отчет по неделям
router.get('/weekly', async (req, res) => {
  const { week_start } = req.query;
  try {
    const result = await callDbFunction('get_weekly_report', [week_start], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Прогресс веса за неделю
router.get('/weight-progress', async (req, res) => {
  const { week_start } = req.query;
  try {
    const result = await callDbFunction('get_weight_report', [week_start], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Прогресс по калориям на день
router.get('/calories-progress', async (req, res) => {
  const { date } = req.query;
  try {
    const result = await callDbFunction('get_calorie_progress', [date], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;
