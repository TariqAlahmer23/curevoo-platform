const request = require('supertest');
const express = require('express');

// 1. عمل محاكاة (Mock) للخدمات والمستودعات لمنع الاتصال الحقيقي بقاعدة البيانات
jest.mock('../../src/modules/patients/patients.repo', () => ({
  getPatientMe: jest.fn(),
  countUpcomingAppointmentsForPatient: jest.fn(),
  getLatestSuccessfulNsclcPredictionForPatient: jest.fn()
}), { virtual: true });

jest.mock('../../src/middlewares/auth.middleware', () => ({
  requireAuth: (req, res, next) => {
    // محاكاة مريض مسجل دخول ولديه معرف sub
    req.user = { sub: 'patient-id-777', role: 'PATIENT' };
    next();
  }
}));

jest.mock('../../src/middlewares/rbac.middleware', () => ({
  requireRole: () => (req, res, next) => next()
}));

const patientsRoutes = require('../../src/modules/patients/patients.routes');
const patientsService = require('../../src/modules/patients/patients.service');
const patientsRepo = require('../../src/modules/patients/patients.repo');

const app = express();
app.use(express.json());
app.use('/api/patients', patientsRoutes);

// ----------------------------------------------------
// 1. White-box Test (اختبار المنطق الداخلي وهيكلة البيانات للـ Profile)
// ----------------------------------------------------
describe('White-box: Patients Service Formatting Logic', () => {
  it('يجب أن تقوم دالة formatPatientProfile بتشكيل وإرجاع البيانات من المستودع بالشكل المتوقع تماماً للعميل', async () => {
    const mockDbProfile = {
      id: 'profile-99',
      userId: 'patient-id-777',
      fullName: 'Ahmad Omar',
      address: 'Damascus',
      age: 29,
      sex: 'MALE',
      medicalHistory: 'No chronic diseases',
      riskFactors: { smoking: false },
      user: { email: 'ahmad@example.com', role: 'PATIENT' }
    };

    // استدعاء دالة الخدمة الحقيقية لفحص مخرجاتها البرمجية داخلياً
    const originalService = jest.requireActual('../../src/modules/patients/patients.service');
    const result = originalService.getMe; 
    
    patientsRepo.getPatientMe.mockResolvedValue(mockDbProfile);
    const profileFormatted = await originalService.getMe('patient-id-777');

    expect(profileFormatted.email).toBe('ahmad@example.com');
    expect(profileFormatted.name).toBe('Ahmad Omar');
    expect(profileFormatted.location).toBe('Damascus');
  });
});

// ----------------------------------------------------
// 2. Black-box Test (اختبار مسارات الـ API والـ HTTP Status Codes)
// ----------------------------------------------------
describe('Black-box: GET /api/patients/dashboard/summary', () => {
  it('يجب أن يرجع حالة 200 وملخص لوحة التحكم للمريض الذي قام بتسجيل الدخول بنجاح', async () => {
    // تجهيز ردود مزيفة من المستودع لمحاكاة دالة getDashboardSummary
    patientsRepo.getPatientMe.mockResolvedValue({ id: 'profile-99', userId: 'patient-id-777' });
    patientsRepo.countUpcomingAppointmentsForPatient.mockResolvedValue(2); // موعدين قادمين
    patientsRepo.getLatestSuccessfulNsclcPredictionForPatient.mockResolvedValue(null); // لا توجد تنبؤات سابقة

    const response = await request(app).get('/api/patients/dashboard/summary');

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.data).toHaveProperty('upcomingAppointments', 2);
    expect(response.body.data.latestAiResult).toBeNull();
  });
});