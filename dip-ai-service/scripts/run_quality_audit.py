from pathlib import Path
import json
import sys


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.reports.quality_audit import format_quality_audit_report, run_quality_audit


REPORTS_DIR = OUTPUT_DIR / "reports"
AUDIT_JSON_FILE = REPORTS_DIR / "dip_ai_quality_audit.json"
AUDIT_TEXT_REPORT_FILE = REPORTS_DIR / "dip_ai_quality_audit_report.txt"


def main() -> None:
    """Run the DIP-AI quality audit and save machine/readable reports."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    audit_result = run_quality_audit()
    AUDIT_JSON_FILE.write_text(
        json.dumps(audit_result, indent=2),
        encoding="utf-8",
    )
    AUDIT_TEXT_REPORT_FILE.write_text(
        format_quality_audit_report(audit_result),
        encoding="utf-8",
    )

    print(
        f"{audit_result['status']} - total issues: {audit_result['total_issues']}"
    )
    print(f"Saved JSON audit: {AUDIT_JSON_FILE}")
    print(f"Saved text report: {AUDIT_TEXT_REPORT_FILE}")


if __name__ == "__main__":
    main()
