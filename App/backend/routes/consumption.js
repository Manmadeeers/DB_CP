import express from 'express';
import { callDbFunction } from '../db.js';
import { withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// POST /api/consumption - добавить съеденный продукт
router.post('/', async (req, res) => {
  const { product_id, quantity, consumed_at } = req.body;
  try {
    const result = await callDbFunction(
      'add_consumed_food',
      [product_id, quantity, consumed_at],
      req.userContext
    );
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// DELETE /api/consumption/:id - удалить запись
router.delete('/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  try {
    const result = await callDbFunction('remove_consumed_food', [id], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// GET /api/consumption/day?date=YYYY-MM-DD - список за день
router.get('/day', async (req, res) => {
  const { date } = req.query;
  try {
    const result = await callDbFunction('get_daily_consumption', [date], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;

