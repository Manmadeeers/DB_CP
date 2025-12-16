const express = require('express');
const router = express.Router();
const pool = require('../db');
const { requireRole } = require('../middleware/auth');

router.use(requireRole('app_admin'));

// GET /api/admin/users
router.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT nutrition.admin_get_all_users() AS data');
    res.json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/admin/users
router.post('/users', async (req, res) => {
  const { username, passwordHash, dailyCalLimit, weeklyCalLimit } = req.body;
  try {
    const result = await pool.query(
      'SELECT nutrition.admin_create_user($1,$2,$3,$4) AS data',
      [username, passwordHash, dailyCalLimit, weeklyCalLimit]
    );
    res.json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /api/admin/users/:id
router.delete('/users/:id', async (req, res) => {
  const id = req.params.id;
  try {
    const result = await pool.query('SELECT nutrition.admin_delete_user($1) AS data', [id]);
    res.json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/admin/admins
router.post('/admins', async (req, res) => {
  const { username, passwordHash } = req.body;
  try {
    const result = await pool.query(
      'SELECT nutrition.admin_create_admin($1,$2) AS data',
      [username, passwordHash]
    );
    res.json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /api/admin/admins/:id
router.delete('/admins/:id', async (req, res) => {
  const id = req.params.id;
  try {
    const result = await pool.query(
      'SELECT nutrition.admin_delete_admin($1) AS data',
      [id]
    );
    res.json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
