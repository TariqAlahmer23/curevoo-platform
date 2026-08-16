const request = require('supertest');
const express = require('express');
const cookieParser = require('cookie-parser');

// 1. محاكاة الـ Rate Limiting والـ CSRF لتجنب أخطاء الاتصال بقاعدة البيانات في الفحص
jest.mock('../../src/middlewares/rate-limit.middleware', () => ({
  createRateLimiter: () => (req, res, next) => next(),
  ipAndEmailKey: () => 'test-key'
}));

jest.mock('../../src/middlewares/csrf.middleware', () => ({
  requireCsrfForCookieAuth: (req, res, next) => next()
}));

// 2. محاكاة الـ Services
jest.mock('../../src/modules/registration/registration.service', () => ({
  createAccount: jest.fn(),
  login: jest.fn()
}), { virtual: true });

jest.mock('../../src/modules/auth/auth.service', () => ({
  login: jest.fn(),
  verifyRefreshToken: jest.fn()
}), { virtual: true });

const authRoutes = require('../../src/modules/auth/auth.routes'); 
const tokenService = require('../../src/modules/auth/token.service');
const authService = require('../../src/modules/auth/auth.service');

const app = express();
app.use(express.json());
app.use(cookieParser());

// معالجة أخطاء الـ Validation لكي ترجع 400 بدلاً من الانهيار بـ 500
app.use('/api/auth', authRoutes);
app.use((err, req, res, next) => {
  if (err.name === 'ZodError' || err.statusCode === 400) {
    return res.status(400).json({ ok: false, error: err.message });
  }
  res.status(500).json({ ok: false, error: 'Internal Server Error' });
});

// ----------------------------------------------------
// 1. White-box Test
// ----------------------------------------------------
describe('White-box: Token Service', () => {
  it('يجب أن يقوم بتوليد التوكن وتشفير البيانات بشكل صحيح داخل الـ Payload', () => {
    const payload = { userId: 'user-123', role: 'PATIENT' };
    
    const token = tokenService.signAccessToken(payload);
    expect(token).toBeDefined();
    
    const decoded = tokenService.decodeTokenClaims(token);
    expect(decoded.sub).toBe(payload.userId);
    expect(decoded.role).toBe(payload.role);
  });
});

// ----------------------------------------------------
// 2. Black-box Test
// ----------------------------------------------------
describe('Black-box: POST /api/auth/login', () => {
  it('يجب أن يرجع حالة 400 إذا تم إرسال إيميل بصيغة خاطئة أو باسوورد قصير', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'wrong-email-format', password: '123' });

    expect(response.statusCode).toBe(400);
    expect(response.body.ok).toBeFalsy();
  });

  it('يجب أن يسجل الدخول بنجاح ويرجع حالة 200 عند إرسال بيانات صحيحة', async () => {
    authService.login.mockResolvedValue({
      accessToken: 'valid-mock-access-token',
      refreshToken: 'valid-mock-refresh-token',
      user: { id: 'user-123', email: 'patient1@example.com', role: 'PATIENT' }
    });

    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'patient1@example.com', password: 'Pass1234!' });

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.accessToken).toBe('valid-mock-access-token');
  });
});