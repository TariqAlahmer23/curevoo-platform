"""Generate the final DIP-AI consensus scientific report."""

from pathlib import Path
import sys


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.reports.consensus_final_report import build_final_report


REPORTS_DIR = OUTPUT_DIR / "reports"
MARKDOWN_REPORT_FILE = (
    REPORTS_DIR / "dip_ai_consensus_final_scientific_report.md"
)
TEXT_REPORT_FILE = (
    REPORTS_DIR / "dip_ai_consensus_final_scientific_report.txt"
)


def main() -> None:
    """Build both Markdown and plain-text final scientific reports."""
    markdown_path = build_final_report(MARKDOWN_REPORT_FILE)
    text_path = build_final_report(TEXT_REPORT_FILE)
    print("Final DIP-AI scientific reports generated successfully.")
    print(f"Markdown report: {markdown_path}")
    print(f"Text report: {text_path}")


if __name__ == "__main__":
    main()
