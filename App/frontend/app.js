// Базовый URL API
const API_BASE = 'http://localhost:3000/api';

// Текущее состояние пользователя
let currentUser = loadUserFromStorage();

function loadUserFromStorage() {
  try {
    const raw = localStorage.getItem('nutrition_user');
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveUserToStorage(user) {
  if (!user) {
    localStorage.removeItem('nutrition_user');
  } else {
    localStorage.setItem('nutrition_user', JSON.stringify(user));
  }
}

function getAuthHeaders() {
  if (!currentUser) return {};
  return {
    'x-user-id': String(currentUser.id),
    'x-user-role': currentUser.role,
  };
}

async function apiRequest(path, options = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
    ...getAuthHeaders(),
  };
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });
  let data;
  try {
    data = await res.json();
  } catch {
    data = { success: false, error: 'Некорректный ответ сервера' };
  }
  if (!res.ok || data.success === false) {
    throw new Error(data.error || `Ошибка ${res.status}`);
  }
  return data;
}

function showToast(message, isError = false) {
  const toast = document.getElementById('globalMessage');
  toast.textContent = message;
  toast.style.display = 'block';
  toast.style.background = isError ? '#b91c1c' : '#111827';
  clearTimeout(showToast._timer);
  showToast._timer = setTimeout(() => {
    toast.style.display = 'none';
  }, 2500);
}

function setAuthUI() {
  const authSection = document.getElementById('authSection');
  const dashboardSection = document.getElementById('dashboardSection');
  const currentUserInfo = document.getElementById('currentUserInfo');
  const logoutBtn = document.getElementById('logoutBtn');
  const adminNavBtn = document.getElementById('adminNavBtn');

  if (currentUser) {
    authSection.style.display = 'none';
    dashboardSection.style.display = 'block';
    logoutBtn.style.display = 'inline-flex';
    currentUserInfo.textContent = `${currentUser.username} (${currentUser.role})`;
    adminNavBtn.style.display = currentUser.role === 'app_admin' ? 'inline-flex' : 'none';
  } else {
    authSection.style.display = 'block';
    dashboardSection.style.display = 'none';
    logoutBtn.style.display = 'none';
    currentUserInfo.textContent = '';
  }
}

function switchTab(tabName) {
  document.querySelectorAll('.tab').forEach((btn) => {
    btn.classList.toggle('tab--active', btn.dataset.tab === tabName);
  });
  document.querySelectorAll('.tab-panel').forEach((panel) => {
    panel.classList.toggle('tab-panel--active', panel.id === tabName);
  });
}

function switchView(viewId) {
  document.querySelectorAll('.nav__item').forEach((btn) => {
    btn.classList.toggle('nav__item--active', btn.dataset.view === viewId);
  });
  document.querySelectorAll('.view').forEach((view) => {
    view.classList.toggle('view--active', view.id === viewId);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  setAuthUI();

  // Tabs (auth)
  document.querySelectorAll('.tab').forEach((btn) => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // Views (user/admin)
  document.querySelectorAll('.nav__item').forEach((btn) => {
    btn.addEventListener('click', () => switchView(btn.dataset.view));
  });

  // AUTH
  const loginForm = document.getElementById('loginForm');
  const registerForm = document.getElementById('registerForm');
  const authMessage = document.getElementById('authMessage');
  const logoutBtn = document.getElementById('logoutBtn');

  loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(loginForm);
    const payload = {
      username: form.get('username'),
      password: form.get('password'),
    };
    try {
      const data = await apiRequest('/auth/login', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      if (data.success && data.user) {
        currentUser = {
          id: data.user.id,
          username: data.user.username,
          role: data.user.role,
        };
        saveUserToStorage(currentUser);
        setAuthUI();
        showToast('Успешный вход');
      } else {
        authMessage.textContent = data.error || 'Ошибка входа';
      }
    } catch (err) {
      authMessage.textContent = err.message;
    }
  });

  registerForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(registerForm);
    const payload = {
      username: form.get('username'),
      password: form.get('password'),
    };
    try {
      const data = await apiRequest('/auth/register', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      authMessage.textContent = data.message || 'Регистрация успешна, войдите';
      switchTab('loginTab');
    } catch (err) {
      authMessage.textContent = err.message;
    }
  });

  logoutBtn.addEventListener('click', async () => {
    try {
      await apiRequest('/auth/logout', { method: 'POST' });
    } catch (_) {
      // игнорируем
    }
    currentUser = null;
    saveUserToStorage(null);
    setAuthUI();
  });

  // USER: профиль
  const loadProfileBtn = document.getElementById('loadProfileBtn');
  const profileForm = document.getElementById('profileForm');

  loadProfileBtn.addEventListener('click', async () => {
    try {
      const data = await apiRequest('/profile');
      if (data.success && data.data) {
        const d = data.data;
        document.getElementById('profileId').value = d.id;
        document.getElementById('profileUsername').value = d.username;
        document.getElementById('profileDaily').value = d.dailyCalorieLimit;
        document.getElementById('profileWeekly').value = d.weeklyCalorieLimit;
      }
    } catch (err) {
      showToast(err.message, true);
    }
  });

  profileForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
      dailyCalorieLimit: Number(document.getElementById('profileDaily').value),
      weeklyCalorieLimit: Number(document.getElementById('profileWeekly').value),
    };
    try {
      await apiRequest('/profile', {
        method: 'PUT',
        body: JSON.stringify(payload),
      });
      showToast('Профиль обновлён');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // USER: вес
  const addWeightForm = document.getElementById('addWeightForm');
  const weightTableBody = document.querySelector('#weightTable tbody');

  async function loadWeightHistory() {
    try {
      const data = await apiRequest('/profile/weight');
      weightTableBody.innerHTML = '';
      (data.data || []).forEach((item) => {
        const tr = document.createElement('tr');
        const date = item.record_date || item.date || '';
        tr.innerHTML = `<td>${date}</td><td>${item.weight}</td>`;
        weightTableBody.appendChild(tr);
      });
    } catch (err) {
      showToast(err.message, true);
    }
  }

  addWeightForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(addWeightForm);
    const payload = {
      date: form.get('date'),
      weight: Number(form.get('weight')),
    };
    try {
      await apiRequest('/profile/weight', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast('Запись веса сохранена');
      loadWeightHistory();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // USER: продукты
  const productsTableBody = document.querySelector('#productsTable tbody');
  const loadProductsBtn = document.getElementById('loadProductsBtn');
  const searchProductsBtn = document.getElementById('searchProductsBtn');
  const productSearchInput = document.getElementById('productSearchInput');
  const createProductForm = document.getElementById('createProductForm');

  async function loadProducts(name) {
    try {
      let data;
      if (name) {
        data = await apiRequest(`/products/search?name=${encodeURIComponent(name)}`);
      } else {
        data = await apiRequest('/products');
      }
      const items = data.data || [];
      productsTableBody.innerHTML = '';
      items.forEach((p) => {
        const tr = document.createElement('tr');
        const portionSize = p.portionSize != null ? p.portionSize : p.portion_size;
        const portionUnit = (p.portionUnit != null ? p.portionUnit : p.portion_unit) || '';
        const portion = `${portionSize} ${portionUnit}`;
        tr.innerHTML = `
          <td>${p.id}</td>
          <td>${p.name}</td>
          <td>${p.caloriesPerPortion ?? p.calories_per_portion}</td>
          <td>${portion}</td>
          <td><button class="btn btn-small btn-outline" data-add-to-menu="${p.id}">В меню</button></td>
        `;
        productsTableBody.appendChild(tr);
      });
    } catch (err) {
      showToast(err.message, true);
    }
  }

  loadProductsBtn.addEventListener('click', () => loadProducts());
  searchProductsBtn.addEventListener('click', () => loadProducts(productSearchInput.value.trim()));

  productsTableBody.addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-add-to-menu]');
    if (!btn) return;
    const id = Number(btn.dataset.addToMenu);
    try {
      await apiRequest('/menu/add', {
        method: 'POST',
        body: JSON.stringify({ product_id: id }),
      });
      showToast('Добавлено в меню');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  createProductForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(createProductForm);
    const payload = {
      name: form.get('name'),
      calories: Number(form.get('calories')),
      portion_size: Number(form.get('portion_size')),
      portion_unit: form.get('portion_unit'),
      protein: Number(form.get('protein') || 0),
      fat: Number(form.get('fat') || 0),
      carbs: Number(form.get('carbs') || 0),
      is_public: form.get('is_public') === 'on',
    };
    try {
      await apiRequest('/products', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast('Продукт создан');
      createProductForm.reset();
      loadProducts();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // USER: меню
  const addToMenuForm = document.getElementById('addToMenuForm');
  const removeFromMenuForm = document.getElementById('removeFromMenuForm');
  const generateWeekMenuForm = document.getElementById('generateWeekMenuForm');
  const getWeekMenuForm = document.getElementById('getWeekMenuForm');
  const getDayMenuForm = document.getElementById('getDayMenuForm');
  const regenerateDayForm = document.getElementById('regenerateDayForm');
  const menuTableBody = document.querySelector('#menuTable tbody');

  function renderWeekMenu(data) {
    menuTableBody.innerHTML = '';
    const days = data.data || [];
    days.forEach((day) => {
      const date = day.date;
      const products = day.products || [];
      products.forEach((p) => {
        const tr = document.createElement('tr');
        const portion = `${p.portionSize} ${p.portionUnit || ''}`;
        tr.innerHTML = `
          <td>${date}</td>
          <td>${p.name}</td>
          <td>${portion}</td>
          <td>${p.caloriesPerPortion}</td>
          <td>${p.quantity ?? 1}</td>
        `;
        menuTableBody.appendChild(tr);
      });
    });
  }

  function renderDayMenu(date, data) {
    menuTableBody.innerHTML = '';
    const products = data.data || [];
    products.forEach((p) => {
      const tr = document.createElement('tr');
      const portion = `${p.portionSize} ${p.portionUnit || ''}`;
      tr.innerHTML = `
        <td>${date}</td>
        <td>${p.name}</td>
        <td>${portion}</td>
        <td>${p.caloriesPerPortion}</td>
        <td>${p.quantity ?? 1}</td>
      `;
      menuTableBody.appendChild(tr);
    });
  }

  addToMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = Number(new FormData(addToMenuForm).get('product_id'));
    try {
      await apiRequest('/menu/add', {
        method: 'POST',
        body: JSON.stringify({ product_id: id }),
      });
      showToast('Продукт добавлен в меню');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  removeFromMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = Number(new FormData(removeFromMenuForm).get('product_id'));
    try {
      await apiRequest('/menu/remove', {
        method: 'POST',
        body: JSON.stringify({ product_id: id }),
      });
      showToast('Продукт удалён из меню');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  generateWeekMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const week_start = new FormData(generateWeekMenuForm).get('week_start');
    try {
      await apiRequest('/menu/generate-week', {
        method: 'POST',
        body: JSON.stringify({ week_start }),
      });
      showToast('Меню на неделю сгенерировано');
      // можно сразу показать меню недели
      const data = await apiRequest(`/menu/week?week_start=${encodeURIComponent(week_start)}`);
      renderWeekMenu(data);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  getWeekMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const week_start = new FormData(getWeekMenuForm).get('week_start');
    try {
      const data = await apiRequest(`/menu/week?week_start=${encodeURIComponent(week_start)}`);
      renderWeekMenu(data);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  getDayMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const date = new FormData(getDayMenuForm).get('date');
    try {
      const data = await apiRequest(`/menu/day?date=${encodeURIComponent(date)}`);
      renderDayMenu(date, data);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  regenerateDayForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const date = new FormData(regenerateDayForm).get('date');
    try {
      await apiRequest('/menu/regenerate-day', {
        method: 'POST',
        body: JSON.stringify({ date }),
      });
      showToast('Меню на день перегенерировано');
      const data = await apiRequest(`/menu/day?date=${encodeURIComponent(date)}`);
      renderDayMenu(date, data);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // USER: потребление
  const addConsumedForm = document.getElementById('addConsumedForm');
  const getDailyConsumptionForm = document.getElementById('getDailyConsumptionForm');
  const consumptionTableBody = document.querySelector('#consumptionTable tbody');

  addConsumedForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = new FormData(addConsumedForm);
    const payload = {
      product_id: Number(form.get('product_id')),
      quantity: Number(form.get('quantity')),
      consumed_at: form.get('consumed_at'),
    };
    try {
      await apiRequest('/consumption', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast('Записано потребление');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  async function loadDailyConsumption(date) {
    try {
      const data = await apiRequest(
        `/consumption/day?date=${encodeURIComponent(date)}`
      );
      const items = data.data || [];
      consumptionTableBody.innerHTML = '';
      items.forEach((c) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${c.id}</td>
          <td>${c.productName}</td>
          <td>${c.quantity}</td>
          <td>${c.calories}</td>
          <td><button class="btn btn-small btn-outline" data-remove-consumed="${c.id}">Удалить</button></td>
        `;
        consumptionTableBody.appendChild(tr);
      });
    } catch (err) {
      showToast(err.message, true);
    }
  }

  getDailyConsumptionForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const date = new FormData(getDailyConsumptionForm).get('date');
    loadDailyConsumption(date);
  });

  consumptionTableBody.addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-remove-consumed]');
    if (!btn) return;
    const id = Number(btn.dataset.removeConsumed);
    try {
      await apiRequest(`/consumption/${id}`, { method: 'DELETE' });
      showToast('Запись удалена');
      const date = new FormData(getDailyConsumptionForm).get('date');
      if (date) loadDailyConsumption(date);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // USER: отчёты
  const dailyReportForm = document.getElementById('dailyReportForm');
  const weeklyReportForm = document.getElementById('weeklyReportForm');
  const caloriesProgressBtn = document.getElementById('caloriesProgressBtn');
  const weightReportBtn = document.getElementById('weightReportBtn');
  const dailyReportBody = document.querySelector('#dailyReportTable tbody');
  const weeklyReportBody = document.querySelector('#weeklyReportTable tbody');
  const reportInfo = document.getElementById('reportInfo');

  function renderDailyReport(date, data) {
    dailyReportBody.innerHTML = '';
    const d = data.data || {};
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${d.date || date}</td>
      <td>${d.totalCalories ?? ''}</td>
      <td>${d.dailyLimit ?? ''}</td>
      <td>${d.percentOfLimit ?? ''}</td>
    `;
    dailyReportBody.appendChild(tr);
  }

  function renderWeeklyReport(data) {
    weeklyReportBody.innerHTML = '';
    const rows = data.data || [];
    rows.forEach((r) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${r.date}</td>
        <td>${r.totalCalories}</td>
        <td>${r.dailyLimit}</td>
        <td>${r.percentOfLimit}</td>
      `;
      weeklyReportBody.appendChild(tr);
    });
  }

  function renderInfo(text) {
    reportInfo.textContent = text || '';
  }

  dailyReportForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const date = new FormData(dailyReportForm).get('date');
    try {
      const data = await apiRequest(`/reports/daily?date=${encodeURIComponent(date)}`);
      renderDailyReport(date, data);
      renderInfo('');
    } catch (err) {
      renderInfo(err.message);
    }
  });

  weeklyReportForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const week_start = new FormData(weeklyReportForm).get('week_start');
    try {
      const data = await apiRequest(
        `/reports/weekly?week_start=${encodeURIComponent(week_start)}`
      );
      renderWeeklyReport(data);
      renderInfo('');
    } catch (err) {
      renderInfo(err.message);
    }
  });

  caloriesProgressBtn.addEventListener('click', async () => {
    const date = new FormData(dailyReportForm).get('date');
    if (!date) return;
    try {
      const data = await apiRequest(
        `/reports/calories-progress?date=${encodeURIComponent(date)}`
      );
      renderDailyReport(date, data);
      renderInfo('Прогресс по калориям обновлён');
    } catch (err) {
      renderInfo(err.message);
    }
  });

  weightReportBtn.addEventListener('click', async () => {
    const week_start = new FormData(weeklyReportForm).get('week_start');
    if (!week_start) return;
    try {
      const data = await apiRequest(
        `/reports/weight-progress?week_start=${encodeURIComponent(week_start)}`
      );
      const w = data.data || {};
      renderInfo(
        `Вес: старт ${w.startWeight ?? '-'} → конец ${w.endWeight ?? '-'}, Δ ${w.weightChange ?? '-'}`
      );
    } catch (err) {
      renderInfo(err.message);
    }
  });

  // USER: экспорт своих продуктов
  const exportUserProductsBtn = document.getElementById('exportUserProductsBtn');
  const userProductsExportArea = document.getElementById('userProductsExportArea');

  exportUserProductsBtn.addEventListener('click', async () => {
    try {
      const data = await apiRequest('/products/export/mine');
      userProductsExportArea.value = JSON.stringify(data.data || [], null, 2);
    } catch (err) {
      userProductsExportArea.value = err.message;
    }
  });

  // ADMIN: пользователи
  const loadUsersBtn = document.getElementById('loadUsersBtn');
  const exportUsersBtn = document.getElementById('exportUsersBtn');
  const usersTableBody = document.querySelector('#usersTable tbody');
  const usersExportArea = document.getElementById('usersExportArea');
  const createUserForm = document.getElementById('createUserForm');
  const createAdminForm = document.getElementById('createAdminForm');
  const updateUserForm = document.getElementById('updateUserForm');
  const deleteUserForm = document.getElementById('deleteUserForm');
  const deleteAdminForm = document.getElementById('deleteAdminForm');

  async function loadUsers() {
    try {
      const data = await apiRequest('/users');
      const items = data.data || [];
      usersTableBody.innerHTML = '';
      items.forEach((u) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${u.id}</td>
          <td>${u.username}</td>
          <td>${u.role}</td>
          <td>${u.dailyCalorieLimit}</td>
          <td>${u.weeklyCalorieLimit}</td>
        `;
        usersTableBody.appendChild(tr);
      });
    } catch (err) {
      showToast(err.message, true);
    }
  }

  loadUsersBtn.addEventListener('click', loadUsers);

  exportUsersBtn.addEventListener('click', async () => {
    try {
      const data = await apiRequest('/users/export');
      usersExportArea.value = JSON.stringify(data.data || [], null, 2);
    } catch (err) {
      usersExportArea.value = err.message;
    }
  });

  createUserForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = new FormData(createUserForm);
    const payload = {
      username: f.get('username'),
      password_hash: f.get('password'),
      daily_cal_limit: Number(f.get('daily_cal_limit')),
      weekly_cal_limit: Number(f.get('weekly_cal_limit')),
    };
    try {
      await apiRequest('/users', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast('Пользователь создан');
      createUserForm.reset();
      loadUsers();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  createAdminForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = new FormData(createAdminForm);
    const payload = {
      username: f.get('username'),
      password_hash: f.get('password'),
      daily_cal_limit: f.get('daily_cal_limit')
        ? Number(f.get('daily_cal_limit'))
        : undefined,
      weekly_cal_limit: f.get('weekly_cal_limit')
        ? Number(f.get('weekly_cal_limit'))
        : undefined,
    };
    try {
      await apiRequest('/users/admins', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast('Админ создан');
      createAdminForm.reset();
      loadUsers();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  updateUserForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = new FormData(updateUserForm);
    const id = Number(f.get('user_id'));
    const payload = {
      daily_cal_limit: Number(f.get('daily_cal_limit')),
      weekly_cal_limit: Number(f.get('weekly_cal_limit')),
    };
    try {
      await apiRequest(`/users/${id}`, {
        method: 'PUT',
        body: JSON.stringify(payload),
      });
      showToast('Лимиты обновлены');
      loadUsers();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  deleteUserForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = Number(new FormData(deleteUserForm).get('user_id'));
    try {
      await apiRequest(`/users/${id}`, { method: 'DELETE' });
      showToast('Пользователь удалён');
      loadUsers();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  deleteAdminForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = Number(new FormData(deleteAdminForm).get('admin_id'));
    try {
      await apiRequest(`/users/admins/${id}`, { method: 'DELETE' });
      showToast('Админ удалён');
      loadUsers();
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // ADMIN: продукты импорт/экспорт
  const exportAllProductsBtn = document.getElementById('exportAllProductsBtn');
  const importProductsBtn = document.getElementById('importProductsBtn');
  const productsImportExportArea = document.getElementById('productsImportExportArea');

  exportAllProductsBtn.addEventListener('click', async () => {
    try {
      const data = await apiRequest('/products/export/all');
      productsImportExportArea.value = JSON.stringify(data.data || [], null, 2);
    } catch (err) {
      productsImportExportArea.value = err.message;
    }
  });

  importProductsBtn.addEventListener('click', async () => {
    let json;
    try {
      json = JSON.parse(productsImportExportArea.value || '[]');
    } catch {
      showToast('Некорректный JSON', true);
      return;
    }
    try {
      await apiRequest('/products/import', {
        method: 'POST',
        body: JSON.stringify({ products: json }),
      });
      showToast('Продукты импортированы');
    } catch (err) {
      showToast(err.message, true);
    }
  });

  // Авто-загрузка некоторых данных при входе
  if (currentUser) {
    loadWeightHistory();
    loadProducts();
  }
});


