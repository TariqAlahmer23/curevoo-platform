# Genomic target prioritization service.
#
# Only the derived artifacts the request path actually opens are copied in
# (~25 MB). The raw pipeline inputs are excluded from the repository entirely —
# see .gitignore at the repository root.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8001

WORKDIR /app

COPY requirements-api.txt .
RUN pip install --no-cache-dir -r requirements-api.txt

COPY app ./app

# Artifacts read at request time.
COPY data/processed/target_ranking_v6_evidence_tiers.csv ./data/processed/
COPY data/processed/gtex_lung_safety_features.csv ./data/processed/
COPY data/external/labels/external_targets_consensus_ncg_civic.csv ./data/external/labels/
COPY outputs/reports/dip_ai_consensus_ncg_civic_metrics.csv ./outputs/reports/
COPY outputs/reports/dip_ai_ncg_leakage_minimized_metrics.csv ./outputs/reports/

# Sample datasets so the upload path can be demonstrated on a fresh deployment.
COPY data/samples ./data/samples

EXPOSE 8001

# Render injects PORT; fall back to 8001 for local runs.
CMD ["sh", "-c", "uvicorn app.api.app:app --host 0.0.0.0 --port ${PORT:-8001}"]
