from pathlib import Path
import json
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR, PROCESSED_DIR
from app.reports.final_outputs import (
    create_category_summary,
    create_dashboard_json,
    create_markdown_report,
    create_tier_summary,
    create_top_targets_table,
    load_v6_results,
)


INPUT_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"
REPORTS_DIR = OUTPUT_DIR / "reports"

TOP_TARGETS_FILE = REPORTS_DIR / "dip_ai_top_targets.csv"
EVIDENCE_TIER_SUMMARY_FILE = REPORTS_DIR / "dip_ai_evidence_tier_summary.csv"
TARGET_CATEGORY_SUMMARY_FILE = REPORTS_DIR / "dip_ai_target_category_summary.csv"
DASHBOARD_PAYLOAD_FILE = REPORTS_DIR / "dip_ai_dashboard_payload.json"
MARKDOWN_REPORT_FILE = REPORTS_DIR / "dip_ai_target_ranking_report.md"


def main() -> None:
    """Build final presentation-ready DIP-AI output files."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    results = load_v6_results(INPUT_FILE)
    top_targets = create_top_targets_table(results)
    evidence_tier_summary = create_tier_summary(results)
    target_category_summary = create_category_summary(results)
    dashboard_payload = create_dashboard_json(results)

    top_targets.to_csv(TOP_TARGETS_FILE, index=False)
    evidence_tier_summary.to_csv(EVIDENCE_TIER_SUMMARY_FILE, index=False)
    target_category_summary.to_csv(TARGET_CATEGORY_SUMMARY_FILE, index=False)
    DASHBOARD_PAYLOAD_FILE.write_text(
        json.dumps(dashboard_payload, indent=2),
        encoding="utf-8",
    )
    create_markdown_report(results, MARKDOWN_REPORT_FILE)

    saved_paths = [
        TOP_TARGETS_FILE,
        EVIDENCE_TIER_SUMMARY_FILE,
        TARGET_CATEGORY_SUMMARY_FILE,
        DASHBOARD_PAYLOAD_FILE,
        MARKDOWN_REPORT_FILE,
    ]

    print("Final DIP-AI outputs built successfully.")
    print("Saved files:")
    for path in saved_paths:
        print(path)


if __name__ == "__main__":
    main()
