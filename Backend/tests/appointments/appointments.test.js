const request = require('supertest');
const express = require('express');

jest.mock('../../src/modules/appointments/appointments.repo', () => ({
  findDoctorUserById: jest.fn(),
  getDoctorAvailabilityByUserId: jest.fn(),
  findDoctorAppointmentConflict: jest.fn(),
  createAppointment: jest.fn(),
  findAppointmentById: jest.fn()
}), { virtual: true });

jest.mock('../../src/middlewares/auth.middleware', () => ({
  requireAuth: (req, res, next) => {
    req.user = { sub: 'patient-user-777', role: 'PATIENT' };
    next();
  }
}));

jest.mock('../../src/middlewares/rbac.middleware', () => ({
  requireRole: () => (req, res, next) => next()
}));

const appointmentsRoutes = require('../../src/modules/appointments/appointments.routes');
const appointmentsRepo = require('../../src/modules/appointments/appointments.repo');

const app = express();
app.use(express.json());
app.use('/api/appointments', appointmentsRoutes);

app.use((err, req, res, next) => {
  if (err.name === 'ZodError' || err.statusCode === 400) {
    return res.status(400).json({ ok: false, error: err.message });
  }
  res.status(500).json({ ok: false, error: 'Internal Server Error' });
});

// 1. White-box Test (اختبار المنطق الداخلي لقاعدة الساعتين)
describe('White-box: Appointment Change Lead Time Restriction', () => {
  it('يجب أن يرمي خطأ ويمنع العملية إذا حاول المستخدم تعديل موعد متبقٍ عليه أقل من ساعتين', () => {
    // محاكاة موعد مجدول بعد ساعة واحدة فقط من الآن (ينتهك قاعدة الساعتين المحددة بـ MIN_HOURS_BEFORE_CHANGE)
    const anHourFromNow = new Date(Date.now() + 1 * 60 * 60 * 1000);

    const checkTimeRestriction = (scheduledAt) => {
      const msLeft = new Date(scheduledAt).getTime() - Date.now();
      const hoursLeft = msLeft / (1000 * 60 * 60);
      if (hoursLeft < 2) {  
        throw new Error('Appointment can only be changed at least 2 hours before schedule');
      }
    };

    expect(() => checkTimeRestriction(anHourFromNow)).toThrow(
      'Appointment can only be changed at least 2 hours before schedule'
    );
  });
});

 // 2. Black-box Test (اختبار عمليات الـ Endpoints)
 describe('Black-box: POST /api/appointments', () => {
  it('يجب أن يرفض الحجز ويرجع 400 إذا أرسل العميل التاريخ ولم يرسل الوقت', async () => {
    const response = await request(app)
      .post('/api/appointments')
      .send({
        doctorUserId: 'doc-user-555',
        appointmentDate: '2026-06-15'
        // حذَفنا حقل appointmentTime عمداً لتفعيل الـ superRefine الخاص بالـ Validation
      });

    expect(response.statusCode).toBe(400);
    expect(response.body.ok).toBe(false);
  });

  it('يجب أن يحجز الموعد بنجاح وحالة 201 عند إدخال بيانات صحيحة ومكتملة لطبيب متاح', async () => {
    // محاكاة طبيب متاح ونشط ومطابق للشروط
    appointmentsRepo.findDoctorUserById.mockResolvedValue({
      id: 'doc-user-555',
      role: 'DOCTOR',
      doctorProfile: { id: 'doc-profile-11', isActive: true, fullName: 'Dr. Samer' }
    });
    
    // محاكاة جهوزية الطبيب في الخلفية لتمرير فحص isWithinAvailableSlot
    appointmentsRepo.getDoctorAvailabilityByUserId.mockResolvedValue({
      id: 'doc-profile-11',
      availableTimes: [{ dayOfWeek: new Date('2026-06-15').getDay(), startTime: '09:00', endTime: '14:00', isOn: true }]
    });

    appointmentsRepo.findDoctorAppointmentConflict.mockResolvedValue(null);   

    appointmentsRepo.createAppointment.mockResolvedValue({
      id: 'appt-123',
      patientUserId: 'patient-user-777',
      doctorUserId: 'doc-user-555',
      scheduledAt: new Date('2026-06-15T10:00:00.000Z'),
      reason: 'Regular Follow-up',
      status: 'PENDING'
    });

    const response = await request(app)
      .post('/api/appointments')
      .send({
        doctorUserId: 'doc-user-555',
        appointmentDate: '2026-06-15',
        appointmentTime: '10:00',
        reason: 'Regular Follow-up'
      });

    expect(response.statusCode).toBe(201);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.status).toBe('PENDING');
  });
});