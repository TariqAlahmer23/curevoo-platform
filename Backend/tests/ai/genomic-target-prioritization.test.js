const request = require('supertest');
const express = require('express');
const path = require('path');

// Mock authentication and role checks so the routes can be exercised in isolation.
jest.mock('../../src/middlewares/auth.middleware', () => ({
  requireAuth: (req, res, next) => {
    req.user = { sub: 'doctor-id-001', role: 'DOCTOR' };
    next();
  }
}));

jest.mock('../../src/middlewares/rbac.middleware', () => ({
  requireRole: () => (req, res, next) => next()
}));

const genomicRoutes = require('../../src/modules/ai/genomic-target-prioritization/genomic-target-prioritization.routes');
const { errorMiddleware } = require('../../src/middlewares/error.middleware');

const app = express();
app.use(express.json());
app.use('/api/ai/genomic-target-prioritization', genomicRoutes);
app.use(errorMiddleware);

const FIXTURES = path.join(__dirname, 'fixtures');

// Minimal upstream payload matching the FastAPI AnalyzeResponse contract.
const upstreamAnalyze = {
  status: 'success',
  run_id: 'runabc123',
  data_source: 'precomputed_cohort',
  generated_at: '2026-08-16T12:00:00Z',
  inputs: {},
  summary: {
    total_targets: 100,
    high_priority_count: 2,
    medium_priority_count: 40,
    low_priority_count: 58,
    externally_supported_targets: 60,
    evidence_tier_counts: {},
    priority_counts: {}
  },
  top_targets: [
    {
      rank: 1,
      gene: 'TP53',
      ranking_score: 0.7467,
      priority: 'High',
      evidence_tier: 'Tier_1_Strong_Integrated_Target',
      target_category: 'Integrated',
      safety_risk: 'High_Normal_Expression',
      safety_score: 0.2,
      normal_lung_tpm: 30.1,
      explanation: 'High mutation burden and LUAD relevance.',
      evidence_tier_explanation: 'Strong integrated evidence.',
      external_evidence_sources: ['NCG', 'CIViC']
    }
  ],
  ml_metrics: {
    available: true,
    accuracy: 0.7347883597883598,
    f1_score: 0.5309941520467836,
    mcc: 0.3655352583389095,
    roc_auc: 0.7490945452254977,
    pr_auc: 0.624683169093729,
    model_name: 'RandomForestClassifier',
    label_mode: 'high_confidence',
    evaluation_strategy: 'stratified_5_fold_cross_validation',
    source_file: 'dip_ai_consensus_ncg_civic_metrics.csv',
    unavailable_reason: null
  },
  report_path: '/reports/runabc123',
  disclaimer: 'Research-use only. This service does not provide diagnosis or treatment decisions.'
};

const upstreamHealth = {
  status: 'ok',
  ok: true,
  service: 'dip-ai-genomic-target-prioritization',
  version: '1.0.0',
  metrics_available: true,
  cohort_ranking_available: true,
  missing_artifacts: []
};

function respond(status, body, asText = false) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    text: async () => (asText ? body : JSON.stringify(body))
  };
}

// The service performs a /health pre-check before every call, so the mock has to
// route by URL rather than returning one canned payload for every request.
function mockUpstream({ health = upstreamHealth, analyze, results, report } = {}) {
  global.fetch = jest.fn().mockImplementation(async (url) => {
    const target = String(url);

    if (target.includes('/health')) return respond(200, health);
    if (target.includes('/analyze')) return analyze || respond(200, upstreamAnalyze);
    if (target.includes('/reports/')) return report || respond(200, '# report\n', true);
    if (target.includes('/results/')) return results || respond(200, upstreamAnalyze);

    return respond(404, { detail: 'not found' });
  });
}

afterEach(() => {
  delete global.fetch;
});

// ----------------------------------------------------------------------------
// Health proxy
// ----------------------------------------------------------------------------

describe('GET /health', () => {
  it('reports the AI service as available when the upstream health check succeeds', async () => {
    mockUpstream();

    const response = await request(app).get('/api/ai/genomic-target-prioritization/health');

    expect(response.statusCode).toBe(200);
    expect(response.body.available).toBe(true);
    expect(response.body.service).toBe('dip-ai-genomic-target-prioritization');
  });

  it('returns 503 with a safe message when the AI service is unreachable', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('ECONNREFUSED 127.0.0.1:8001'));

    const response = await request(app).get('/api/ai/genomic-target-prioritization/health');

    expect(response.statusCode).toBe(503);
    expect(response.body.error.code).toBe('AI_SERVICE_UNAVAILABLE');
    expect(response.body.error.message).not.toMatch(/ECONNREFUSED|Traceback|at Object/);
  });
});

// ----------------------------------------------------------------------------
// Analyze
// ----------------------------------------------------------------------------

describe('POST /analyze', () => {
  it('runs the reference cohort when no files are uploaded', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '5');

    expect(response.statusCode).toBe(200);
    expect(response.body.dataSource).toBe('precomputed_cohort');
    expect(response.body.topTargets[0].gene).toBe('TP53');
    expect(response.body.topTargets[0].evidenceTier).toBe('Tier_1_Strong_Integrated_Target');
    expect(response.body.topTargets[0].safetyRisk).toBe('High_Normal_Expression');
    expect(response.body.topTargets[0].explanation).toEqual(expect.any(String));
  });

  it('exposes the persisted ML metrics in camelCase', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '5');

    expect(response.body.mlMetrics.available).toBe(true);
    expect(response.body.mlMetrics.accuracy).toBeCloseTo(0.7347883597883598, 10);
    expect(response.body.mlMetrics.f1Score).toBeCloseTo(0.5309941520467836, 10);
    expect(response.body.mlMetrics.mcc).toBeCloseTo(0.3655352583389095, 10);
    expect(response.body.mlMetrics.rocAuc).toBeCloseTo(0.7490945452254977, 10);
    expect(response.body.mlMetrics.prAuc).toBeCloseTo(0.624683169093729, 10);
  });

  it('always returns the research-use disclaimer', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '5');

    expect(response.body.disclaimer).toBe(
      'Research-use only. This service does not provide diagnosis or treatment decisions.'
    );
  });

  // Regression guard for DEF-01. The upstream mock is deliberately healthy and
  // would answer 200, so this only passes if the backend refuses the request
  // itself. Asserting that /analyze is never called is the part that matters:
  // previously the lone file was dropped and the run silently became a cohort
  // run, returning 200 with data the caller never uploaded.
  it('rejects an upload that provides only the mutation file', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .attach('mutationsFile', path.join(FIXTURES, 'mutations.csv'));

    expect(response.statusCode).toBe(400);
    expect(response.body.ok).toBe(false);
    expect(response.body.error.code).toBe('GENOMIC_ANALYSIS_INPUT_INVALID');

    const calledUrls = global.fetch.mock.calls.map(([url]) => String(url));
    expect(calledUrls.some((url) => url.includes('/analyze'))).toBe(false);
  });

  it('rejects an upload that provides only the expression file', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .attach('expressionFile', path.join(FIXTURES, 'expression.csv'));

    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('GENOMIC_ANALYSIS_INPUT_INVALID');

    const calledUrls = global.fetch.mock.calls.map(([url]) => String(url));
    expect(calledUrls.some((url) => url.includes('/analyze'))).toBe(false);
  });

  it('still runs the reference cohort when neither file is uploaded', async () => {
    mockUpstream();

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '5');

    expect(response.statusCode).toBe(200);
    expect(response.body.dataSource).toBe('precomputed_cohort');
  });

  it('rejects an unsupported file type', async () => {
    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .attach('mutationsFile', path.join(FIXTURES, 'chart.png'))
      .attach('expressionFile', path.join(FIXTURES, 'expression.csv'));

    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('INVALID_FILE_TYPE');
  });

  it('rejects a topN outside the accepted range', async () => {
    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '9999');

    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('does not leak an upstream Python traceback to the client', async () => {
    mockUpstream({
      analyze: respond(500, {
        detail: 'Traceback (most recent call last):\n  File "app.py", line 1\nValueError: boom'
      })
    });

    const response = await request(app)
      .post('/api/ai/genomic-target-prioritization/analyze')
      .field('topN', '5');

    expect(response.statusCode).toBeGreaterThanOrEqual(500);
    const serialized = JSON.stringify(response.body);
    expect(serialized).not.toMatch(/Traceback|File "app\.py"|ValueError/);
  });
});

// ----------------------------------------------------------------------------
// Stored results
// ----------------------------------------------------------------------------

describe('GET /results/:runId', () => {
  it('returns a stored run', async () => {
    mockUpstream();

    const response = await request(app).get(
      '/api/ai/genomic-target-prioritization/results/runabc123'
    );

    expect(response.statusCode).toBe(200);
    expect(response.body.runId).toBe('runabc123');
  });

  it('returns 404 for an unknown run id', async () => {
    mockUpstream({ results: respond(404, { detail: 'Analysis run not found' }) });

    const response = await request(app).get(
      '/api/ai/genomic-target-prioritization/results/doesnotexist'
    );

    expect(response.statusCode).toBe(404);
    expect(response.body.error.code).toBe('GENOMIC_ANALYSIS_RESULT_NOT_FOUND');
  });
});

describe('GET /results/:runId/report', () => {
  it('returns the generated Markdown report', async () => {
    mockUpstream({ report: respond(200, '# DIP-AI Target Ranking Report\n', true) });

    const response = await request(app).get(
      '/api/ai/genomic-target-prioritization/results/runabc123/report'
    );

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toMatch(/text\/markdown/);
    expect(response.text).toContain('DIP-AI Target Ranking Report');
  });
});
