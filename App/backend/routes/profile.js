import express from 'express';
import { callDbFunction } from '../db.js';
import { withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// GET /api/profile
router.get('/profile', async (req, res) => {
  try {
    const result = await callDbFunction('get_my_profile', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// PUT /api/profile
router.put('/profile', async (req, res) => {
  const { dailyCalorieLimit, weeklyCalorieLimit } = req.body;
  try {
    const result = await callDbFunction(
      'update_my_profile',
      [dailyCalorieLimit, weeklyCalorieLimit],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/profile/weight
router.get('/profile/weight', async (req, res) => {
  try {
    const result = await callDbFunction('get_weight_history', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/profile/weight
router.post('/profile/weight', async (req, res) => {
  const { date, weight } = req.body;
  try {
    const result = await callDbFunction('add_weight_record', [date, weight], req.userContext);
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

export default router;
