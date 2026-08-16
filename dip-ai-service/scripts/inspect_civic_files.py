"""Inspect local CIViC nightly TSV files and save a readable report."""

from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.data.civic_label_builder import read_civic_tsv


CIVIC_DIR = ROOT_DIR / "data" / "external" / "labels" / "civic"
REPORT_FILE = OUTPUT_DIR / "reports" / "civic_file_inspection_report.txt"


def main() -> None:
    """Read, display, and report all downloaded CIViC TSV files."""
    tsv_files = sorted(CIVIC_DIR.glob("*.tsv"))
    if not tsv_files:
        raise FileNotFoundError(f"No CIViC TSV files found in: {CIVIC_DIR}")

    report_sections = [
        "CIViC File Inspection Report",
        "============================",
        f"Directory: {CIVIC_DIR}",
        f"TSV files found: {len(tsv_files)}",
        "",
    ]

    for path in tsv_files:
        dataframe = read_civic_tsv(path)
        section = _format_file_section(path, dataframe)
        report_sections.append(section)
        print(section)

    REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)
    REPORT_FILE.write_text("\n".join(report_sections), encoding="utf-8")
    print(f"Saved inspection report: {REPORT_FILE}")


def _format_file_section(path: Path, dataframe: pd.DataFrame) -> str:
    with pd.option_context(
        "display.max_columns",
        None,
        "display.max_colwidth",
        120,
        "display.width",
        240,
    ):
        preview = dataframe.head(5).to_string(index=False)

    return "\n".join(
        [
            f"File: {path.name}",
            f"Shape: {dataframe.shape}",
            f"Columns ({len(dataframe.columns)}):",
            ", ".join(str(column) for column in dataframe.columns),
            "First 5 rows:",
            preview,
            "",
        ]
    )


if __name__ == "__main__":
    main()
