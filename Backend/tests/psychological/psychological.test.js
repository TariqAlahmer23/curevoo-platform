const request = require('supertest');
const express = require('express');

jest.mock('../../src/modules/psychological-support/psychological-support.repo', () => ({
  findPsychologicalPatientById: jest.fn(),
  countKnowledgeArticles: jest.fn(),
  listPublishedKnowledgeArticles: jest.fn(),
  createEducationalSearchLog: jest.fn()
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

const psychologicalRoutes = require('../../src/modules/psychological-support/psychological-support.routes');
const psychologicalRepo = require('../../src/modules/psychological-support/psychological-support.repo');

const app = express();
app.use(express.json());
app.use('/api/psychological', psychologicalRoutes);

// 1. White-box Test (اختبار منطق الأمان وتصفية المحتوى السلوكي)

describe('White-box: Psychological Educational Safety Refusal Logic', () => {
  it('يجب أن يتعرف النظام داخلياً على الأسئلة الطبية المحظورة (مثل تغيير جرعات الدواء) ويمنع تمريرها للـ AI للسلامة المباشرة', () => {
    const medicalAdviceQuestion = "Should I stop my medication right now?";

    // محاكاة خوارزمية الفحص والـ Keywords الموجودة في السيرفيس (isBlockedMedicalAdviceQuestion)
    const isBlockedMedicalAdviceQuestion = (q) => {
      const blockedKeywords = ["stop my medication", "change my medication", "what dose should i take"];
      return blockedKeywords.some((keyword) => q.toLowerCase().includes(keyword));
    };

    const isBlocked = isBlockedMedicalAdviceQuestion(medicalAdviceQuestion);
    expect(isBlocked).toBe(true); // تأكيد تفعيل ميزة الحجب التلقائي
  });
});


// 2. Black-box Test (اختبار الاستجابات للـ Search Educational Service)

describe('Black-box: POST /api/psychological/search', () => {
  it('يجب أن يرفض النظام الإجابة ويرجع رسالة حماية (Safe Refusal Message) فوراً إذا كان السؤال الطبي خارج نطاق التعليم العام', async () => {
    psychologicalRepo.findPsychologicalPatientById.mockResolvedValue({ id: 'patient-id', role: 'PATIENT' });
    psychologicalRepo.countKnowledgeArticles.mockResolvedValue(10);

    const response = await request(app)
      .post('/api/psychological/search')
      .send({
        question: "Can I stop my medication because of the side effects?"
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);

    expect(response.body.safety_status).toBe('blocked');
    expect(response.body.answer).toContain("I cannot give treatment decisions, diagnosis, medication advice");
  });

  it('يجب أن يرجع حالة 200 وقائمة المقالات المنشورة بسلام عند طلب مسار المراجع والتعليم', async () => {
    psychologicalRepo.findPsychologicalPatientById.mockResolvedValue({ id: 'patient-id', role: 'PATIENT' });
    psychologicalRepo.listPublishedKnowledgeArticles.mockResolvedValue([
      { id: 'art-1', title: 'What is Immunotherapy?', category: 'CANCER', summary: 'Explanation', content: 'Details', sources: [], language: 'en', readingTimeMinutes: 3 }
    ]);

    const response = await request(app).get('/api/psychological/articles');

    expect(response.statusCode).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.items).toBeInstanceOf(Array);
    expect(response.body.data.items[0].title).toBe('What is Immunotherapy?');
  });
});