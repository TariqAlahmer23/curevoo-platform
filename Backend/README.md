# Curevoo Backend

توثيق المشروع تم تبسيطه ليكون في أقل عدد ممكن من الملفات.

## الملفات المعتمدة حالياً

- `README.md` (هذا الملف): نظرة عامة + تشغيل + ملاحظات مهمة.
- `ENDPOINTS.md`: جميع الـ API endpoints بشكل عملي للتجربة والربط (Postman-ready).

## نظرة عامة

Backend مبني بـ:

- Node.js + Express
- Prisma + PostgreSQL
- JWT Authentication + RBAC
- Zod Validation

الموديولات الأساسية:

- `auth`
- `registration`
- `patients`
- `appointments`
- `doctors` (profile/settings/photo/availability)

## تشغيل المشروع

1. تثبيت الحزم:

```bash
npm install
```

2. إعداد `.env` (حد أدنى):

```env
DATABASE_URL="postgresql://user:password@localhost:5432/curevoo"
JWT_ACCESS_SECRET="your-access-secret"
JWT_REFRESH_SECRET="your-refresh-secret"
PORT=5432
```

3. تحديث Prisma client:

```bash
npx prisma generate
```

4. تشغيل السيرفر:

```bash
npm start
```

## تشغيل وحدات الذكاء الاصطناعي محلياً

تم ربط التطبيق مع وحدتين AI:

- `Cure` عبر Rasa (تشخيص مبكر/محادثة)
- `Curevoo_Resistance_Prediction` عبر FastAPI (NSCLC prediction)

التشغيل المحلي الموحّد:

1. تجهيز virtualenvs وتثبيت الاعتمادات:

```bash
npm run ai:setup
```

مهم:
- وحدة `Cure` تحتاج Python `3.8-3.10` (يفضّل 3.10) بسبب Rasa.
- وحدة `Curevoo_Resistance_Prediction` تعمل بشكل مستقر على Python `3.9-3.12` مع الحزم الحالية.

إذا جهازك يستخدم إصدار أحدث (مثل 3.13)، مرّر مسار بايثون 3.10/3.11 إلى السكربت:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ai/setup-venvs.ps1 -CurePythonExe "C:\Path\To\Python310\python.exe" -ResistancePythonExe "python"
```

إذا أردت تجهيز وحدة المقاومة فقط مؤقتاً:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ai/setup-venvs.ps1 -SkipCure
```

2. تشغيل كل خدمات AI محلياً (خلفية + logs):

```bash
npm run ai:start
```

تشغيل وحدة المقاومة فقط:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ai/start-local-ai.ps1 -SkipCure
```

3. التحقق من الحالة:

```bash
npm run ai:status
```

4. إيقاف الخدمات:

```bash
npm run ai:stop
```

خريطة المنافذ المحلية المستخدمة:

- `Rasa`: `http://127.0.0.1:5005`
- `Cure ML service`: `http://127.0.0.1:8000`
- `Cure image service`: `http://127.0.0.1:8010`
- `NSCLC FastAPI`: `http://127.0.0.1:8002`

ملاحظة: تم تخصيص `8002` لوحدة NSCLC لتفادي تعارضها مع منفذ `8000` الخاص بـ Cure ML.

## اختبار الـ API

- التوثيق التفصيلي: `ENDPOINTS.md`
- مجموعة Postman الجاهزة: `Curevoo.postman_collection.json`

## ملاحظات مهمة

- بعض العمليات تعتمد على Migration قاعدة البيانات.
- إذا ظهر خطأ Prisma مثل `Schema engine error`:
  - تأكد أن PostgreSQL شغّال على نفس `DATABASE_URL`.
  - تأكد من صلاحيات المستخدم وقابلية الاتصال.

## المسارات الأساسية (مختصر)

- `GET /health`
- ` /api/auth/*`
- ` /api/registration/*`
- ` /api/patients/*`
- ` /api/patients/appointments/*`
- ` /api/doctor/*`
- ` /api/doctors/*`

