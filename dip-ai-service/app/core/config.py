from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]

DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
EXTERNAL_DIR = DATA_DIR / "external"
GTEX_DIR = EXTERNAL_DIR / "gtex"
LABELS_DIR = EXTERNAL_DIR / "labels"
OUTPUT_DIR = BASE_DIR / "outputs"
REPORTS_DIR = OUTPUT_DIR / "reports"
RUNS_DIR = REPORTS_DIR / "runs"

RNA_FILE = PROCESSED_DIR / "combined_rna_expression_mapped.csv"
MUTATIONS_FILE = PROCESSED_DIR / "combined_mutations_clean.csv"
CLINICAL_FILE = PROCESSED_DIR / "clinical_clean.csv"
TARGET_CANDIDATES_FILE = PROCESSED_DIR / "target_candidates_v1.csv"

# Pipeline artifacts consumed by the prioritization API.
RANKING_V6_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
SAFETY_FEATURES_FILE = PROCESSED_DIR / "gtex_lung_safety_features.csv"
CONSENSUS_LABELS_FILE = LABELS_DIR / "external_targets_consensus_ncg_civic.csv"

# Persisted model-evaluation outputs. Metrics are always read from these files;
# the API never computes or invents evaluation numbers at request time.
CONSENSUS_METRICS_FILE = REPORTS_DIR / "dip_ai_consensus_ncg_civic_metrics.csv"
LEAKAGE_MINIMIZED_METRICS_FILE = REPORTS_DIR / "dip_ai_ncg_leakage_minimized_metrics.csv"
