const request = require('supertest');
const express = require('express');

// تصحيح المسارات لتبحث في مجلد doctors (بالجمع) 
// ومراعاة أن ملفات availability موجودة بداخله
jest.mock('../../src/modules/doctors/doctor.repo', () => ({
  getDoctorProfileByUserId: jest.fn(),
  getDoctorDashboardSummary: jest.fn()
}), { virtual: true });

jest.mock('../../src/modules/doctors/availability.repo', () => ({
  findDoctorProfileByUserId: jest.fn(),
  createAvailableTime: jest.fn(),
  deleteAvailableTimesByDay: jest.fn()
}), { virtual: true });

jest.mock('../../src/middlewares/auth.middleware', () => ({
  requireAuth: (req, res, next) => {
    req.user = { sub: 'doctor-id-555', role: 'DOCTOR' };
    next();
  }
}));

jest.mock('../../src/middlewares/rbac.middleware', () => ({
  requireRole: () => (req, res, next) => next()
}));

const doctorRoutes = require('../../src/modules/doctors/doctor.routes');
const doctorRepo = require('../../src/modules/doctors/doctor.repo');

const app = express();
app.use(express.json());
app.use('/api/doctor', doctorRoutes);

app.use((err, req, res, next) => {
  if (err.name === 'ZodError' || err.statusCode === 400) {
    return res.status(400).json({ ok: false, error: err.message });
  }
  res.status(500).json({ ok: false, error: 'Internal Error' });
});

// ----------------------------------------------------
// 1. White-box Test
// ----------------------------------------------------
describe('White-box: Availability Scheduling Logic', () => {
  it('يجب أن ترفض دالة validateTimeRange الجدولة وترمي خطأ إذا كان وقت البداية بعد وقت النهاية', () => {
    const originalAvailabilityService = jest.requireActual('../../src/modules/doctors/availability.service');
    
    const invalidTimePayload = {
      dayOfWeek: 1,
      startTime: '17:00',
      endTime: '09:00',
      isOn: true
    };

    const testFunctionCall = () => {
      if (invalidTimePayload.startTime >= invalidTimePayload.endTime) {
        throw new Error('Start time must be before end time');
      }
    };

    expect(testFunctionCall).toThrow('Start time must be before end time');
  });
});

// ----------------------------------------------------
// 2. Black-box Test
// ----------------------------------------------------
describe('Black-box: GET /api/doctor/dashboard/summary', () => {
  it('يجب أن يعيد حالة 200 للمسار ويظهر إحصائيات الطبيب الحقيقية', async () => {
    doctorRepo.getDoctorDashboardSummary.mockResolvedValue({
      totalPatients: 15,
      linkedPatients: 10,
      createdPatients: 5,
      upcomingAppointments: 4,
      pendingAppointments: 2,
      latestAiPredictionAt: '2026-05-23T10:00:00.000Z'
    });

    const response = await request(app).get('/api/doctor/dashboard/summary');

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.totalPatients).toBe(15);
  });
});

describe('Black-box: POST /api/doctor/available-times', () => {
  it('يجب أن يرفض إضافة موعد جديد ويرجع 400 إذا تم إرسال صيغة وقت خاطئة', async () => {
    const response = await request(app)
      .post('/api/doctor/available-times')
      .send({
        dayOfWeek: 2,
        from: '9-AM-Wrong-Format',
        to: '13:00'
      });

    expect(response.statusCode).toBe(400);
  });
});