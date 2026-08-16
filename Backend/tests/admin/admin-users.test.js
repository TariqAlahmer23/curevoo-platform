const request = require('supertest');
const express = require('express');

// تصحيح المسارات بإضافة مجلد src
jest.mock('../../src/modules/admin-users/admin-users.service', () => ({
  listDoctorsByAdmin: jest.fn(),
  deleteDoctorByAdmin: jest.fn()
}), { virtual: true });

jest.mock('../../src/middlewares/auth.middleware', () => ({
  requireAuth: (req, res, next) => {
    req.user = { sub: 'admin-id-111', role: 'ADMIN' };
    next();
  }
}));

jest.mock('../../src/middlewares/rbac.middleware', () => ({
  requireRole: () => (req, res, next) => next()
}));

const adminRoutes = require('../../src/modules/admin-users/admin-users.routes');
const adminService = require('../../src/modules/admin-users/admin-users.service');

const app = express();
app.use(express.json());
app.use('/api/admin/users', adminRoutes);

// ----------------------------------------------------
// 1. White-box Test
// ----------------------------------------------------
describe('White-box: Admin Service Security Logic', () => {
  it('يجب أن يرمي خطأ برمجي ويمنع الحذف إذا حاول المسؤول حذف نفسه', async () => {
    const originalAdminService = jest.requireActual('../../src/modules/admin-users/admin-users.service');
    
    await expect(
      originalAdminService.deleteDoctorByAdmin('admin-id-111', 'admin-id-111')
    ).rejects.toThrow('Admin cannot delete their own account from this endpoint');
  });
});

// ----------------------------------------------------
// 2. Black-box Test
// ----------------------------------------------------
describe('Black-box: GET /api/admin/users/doctors', () => {
  it('يجب أن يرجع حالة 200 وقائمة الأطباء للمسؤول', async () => {
    adminService.listDoctorsByAdmin.mockResolvedValue({
      items: [{ id: 'doc-1', name: 'Dr. Samer' }]
    });

    const response = await request(app).get('/api/admin/users/doctors');

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.items[0].name).toBe('Dr. Samer');
  });
});