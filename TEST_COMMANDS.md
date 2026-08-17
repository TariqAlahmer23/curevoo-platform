# Test Commands

Every command used to produce [TESTING_REPORT.md](TESTING_REPORT.md), in the
order a reviewer would run them. All are reproducible from a clean checkout.

## Prerequisites

| Requirement | Used for |
| --- | --- |
| Python 3.11 with `pip install -r dip-ai-service/requirements.txt` | AI service tests |
| Node.js ≥ 18.18 with `npm install` in `Backend/` | Backend tests |
| Flutter 3 with `flutter pub get` in `Frontend/` | Frontend tests |
| PostgreSQL on `localhost:5432` | Backend integration and login only |

The AI service test suite and the frontend suite need **no** running server and
no database. They can be run immediately after installing dependencies.

---

## 1. AI service (pytest)

Full suite — 40 tests:

```bash
cd dip-ai-service && python -m pytest tests -q
```

White-box suite only — 18 tests:

```bash
cd dip-ai-service && python -m pytest tests/test_prioritization_whitebox.py -v
```

API surface only — 8 tests:

```bash
cd dip-ai-service && python -m pytest tests/test_prioritization_api.py -v
```

## 2. Backend (Jest)

Full suite — 28 tests:

```bash
cd Backend && npm test
```

Genomic module only — 12 tests, no database required:

```bash
cd Backend && npx jest tests/ai --runInBand
```

With coverage:

```bash
cd Backend && npm run test:coverage
```

## 3. Frontend (Flutter)

Static analysis:

```bash
cd Frontend && flutter analyze
```

Unit and widget suite — 9 passed, 1 skipped:

```bash
cd Frontend && flutter test
```

Release build:

```bash
cd Frontend && flutter build web --release --dart-define=API_BASE_URL=https://curevoo-backend.onrender.com/api
```

## 4. End-to-end

The genomic widget test is skipped unless a live backend and a valid `DOCTOR`
token are supplied, so the default suite never depends on a running server.

Obtain a token:

```bash
curl -s -X POST https://curevoo-backend.onrender.com/api/auth/login -H "Content-Type: application/json" -d '{"email":"doctor@curevoo.local","password":"Doctor@12345"}'
```

Run the end-to-end test with it:

```bash
cd Frontend && flutter test test/genomic_target_prioritization_test.dart --dart-define=E2E_API_BASE_URL=https://curevoo-backend.onrender.com/api --dart-define=E2E_ACCESS_TOKEN=<token>
```

Substitute `http://127.0.0.1:3000/api` to run against a local backend instead.

---

## 5. Manual API checks

### 5.1 AI service, called directly

```bash
curl -s http://127.0.0.1:8001/health
```

```bash
curl -s http://127.0.0.1:8001/metrics
```

```bash
curl -s -X POST "http://127.0.0.1:8001/analyze?top_n=5"
```

```bash
curl -s -X POST "http://127.0.0.1:8001/analyze?top_n=5" -F "mutations_file=@dip-ai-service/data/samples/sample_mutations.csv" -F "expression_file=@dip-ai-service/data/samples/sample_rna_expression.csv"
```

Negative cases — expect 400, 404 and 422 respectively:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "http://127.0.0.1:8001/analyze?top_n=5" -F "mutations_file=@dip-ai-service/data/samples/sample_mutations.csv"
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8001/results/doesnotexist99
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "http://127.0.0.1:8001/analyze?top_n=99999"
```

### 5.2 Backend API

Export a token first:

```bash
export TOKEN=$(curl -s -X POST https://curevoo-backend.onrender.com/api/auth/login -H "Content-Type: application/json" -d '{"email":"doctor@curevoo.local","password":"Doctor@12345"}' | python -c "import sys,json;print(json.load(sys.stdin)['data']['accessToken'])")
```

Health proxy:

```bash
curl -s -H "Authorization: Bearer $TOKEN" https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/health
```

Reference cohort:

```bash
curl -s -X POST https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/analyze -H "Authorization: Bearer $TOKEN" -F "topN=5"
```

Uploaded datasets:

```bash
curl -s -X POST https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/analyze -H "Authorization: Bearer $TOKEN" -F "topN=5" -F "mutationsFile=@dip-ai-service/data/samples/sample_mutations.csv;type=text/csv" -F "expressionFile=@dip-ai-service/data/samples/sample_rna_expression.csv;type=text/csv"
```

Negative cases — expect 401, 400 and 404 respectively:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/health
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/analyze -H "Authorization: Bearer $TOKEN" -F "topN=9999"
```

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $TOKEN" https://curevoo-backend.onrender.com/api/ai/genomic-target-prioritization/results/doesnotexist99
```

### 5.3 Reproducing the service-down test (EH-01, EH-02)

Stop the local AI service, then call the local backend. Both calls must return
`503 AI_SERVICE_UNAVAILABLE` with no upstream detail in the body.

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:3000/api/ai/genomic-target-prioritization/health
```

Restart it afterwards:

```bash
cd dip-ai-service && python -m uvicorn app.api.app:app --host 127.0.0.1 --port 8001
```

---

## 6. Running the whole stack

```bash
powershell -ExecutionPolicy Bypass -File start-full-project.ps1
```

Starts PostgreSQL, the AI service, the backend and the built frontend, skipping
any port already in use.

## 7. Regenerating the sample datasets

```bash
cd dip-ai-service && python scripts/build_sample_upload_datasets.py
```
