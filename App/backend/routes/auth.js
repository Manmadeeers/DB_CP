import express from 'express';
import { callDbFunction } from '../db.js';
import { withUserContext } from '../middleware/auth.js';

const router = express.Router();
router.use(withUserContext);

// Register (app_user)
router.post('/register', async (req, res) => {
  const { username, password } = req.body;
  try {
    const result = await callDbFunction('user_register', [username, password]);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const result = await callDbFunction('user_login', [username, password]);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// Logout
router.post('/logout', async (req, res) => {
  try {
    const result = await callDbFunction('user_logout', [], req.userContext);
    res.json(result);
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

export default router;
