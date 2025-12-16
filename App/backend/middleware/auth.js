/**
 * Простейшая проверка роли по заголовку x-user-role.
 * Ожидается, что клиент передает id и роль, полученные при логине.
 */
export const requireRole = (role) => (req, res, next) => {
  const currentRole = req.header('x-user-role');
  if (currentRole !== role) {
    return res.status(403).json({ success: false, error: 'Access denied' });
  }
  next();
};

/**
 * Забираем userId/role из заголовков и сохраняем в объект запроса,
 * чтобы передавать в callDbFunction для установки контекста.
 */
export const withUserContext = (req, _res, next) => {
  req.userContext = {
    userId: req.header('x-user-id') || null,
    role: req.header('x-user-role') || null,
  };
  next();
};
