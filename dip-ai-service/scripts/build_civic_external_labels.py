"""Build standardized positive gene labels from local CIViC exports."""

from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.data.civic_label_builder import build_civic_external_labels


CIVIC_DIR = ROOT_DIR / "data" / "external" / "labels" / "civic"
OUTPUT_FILE = (
    ROOT_DIR / "data" / "external" / "labels" / "external_targets_civic.csv"
)
SUMMARY_FILE = OUTPUT_DIR / "reports" / "civic_external_labels_summary.txt"


def main() -> None:
    """Build, save, summarize, and print CIViC external gene labels."""
    labels = build_civic_external_labels(CIVIC_DIR)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_FILE.parent.mkdir(parents=True, exist_ok=True)
    labels.to_csv(OUTPUT_FILE, index=False)

    files_used = sorted(
        [
            *CIVIC_DIR.glob("*GeneSummaries.tsv"),
            *CIVIC_DIR.glob("*ClinicalEvidenceSummaries.tsv"),
        ]
    )
    summary = _build_summary(labels, files_used)
    SUMMARY_FILE.write_text(summary, encoding="utf-8")

    print(summary)
    print(f"Saved CIViC labels: {OUTPUT_FILE}")
    print(f"Saved CIViC summary: {SUMMARY_FILE}")


def _build_summary(labels: pd.DataFrame, files_used: list[Path]) -> str:
    evidence_counts = labels["evidence_type"].value_counts().to_string()
    first_genes = ", ".join(labels["gene_name"].head(50).astype(str))
    return "\n".join(
        [
            "CIViC External Labels Summary",
            "=============================",
            "Files used:",
            *[f"- {path}" for path in files_used],
            f"Total CIViC positive genes: {len(labels)}",
            "",
            "Evidence type counts",
            "--------------------",
            evidence_counts,
            "",
            "First 50 genes",
            "--------------",
            first_genes,
            "",
        ]
    )


if __name__ == "__main__":
    main()
