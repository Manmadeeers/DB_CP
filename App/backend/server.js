import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';

import authRoutes from './routes/auth.js';
import usersRoutes from './routes/users.js';
import productsRoutes from './routes/products.js';
import menuRoutes from './routes/menu.js';
import reportsRoutes from './routes/reports.js';
import profileRoutes from './routes/profile.js';
import consumptionRoutes from './routes/consumption.js';

import dotenv from 'dotenv';
dotenv.config();

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Маршруты
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/products', productsRoutes);
app.use('/api/menu', menuRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api', profileRoutes); // profile + weight
app.use('/api/consumption', consumptionRoutes);

// Проверка сервера
app.get('/', (req, res) => res.send('Backend is running!'));

// Запуск сервера
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}/`));
