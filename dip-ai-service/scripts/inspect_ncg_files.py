from pathlib import Path
import sys

import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.data.ncg_label_builder import find_ncg_files


REQUESTED_NCG_DIR = ROOT_DIR / "data" / "external" / "labels" / "ncg"
FALLBACK_NCG_DIR = ROOT_DIR / "data" / "external" / "labels"
REPORT_FILE = OUTPUT_DIR / "reports" / "ncg_file_inspection_report.txt"


def main() -> None:
    """Inspect downloaded NCG source files and save a readable report."""
    ncg_dir = _resolve_ncg_dir()
    REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "NCG File Inspection Report",
        "==========================",
        f"Requested NCG directory: {REQUESTED_NCG_DIR}",
        f"Directory used: {ncg_dir}",
        "",
    ]

    files = find_ncg_files(ncg_dir)
    if not files:
        lines.append("No supported NCG files found.")

    for path in files:
        lines.extend(_inspect_file(path))
        lines.append("")

    report = "\n".join(lines).rstrip() + "\n"
    REPORT_FILE.write_text(report, encoding="utf-8")
    print(report)
    print(f"Saved report: {REPORT_FILE}")


def _resolve_ncg_dir() -> Path:
    requested_files = find_ncg_files(REQUESTED_NCG_DIR)
    if requested_files:
        return REQUESTED_NCG_DIR

    return FALLBACK_NCG_DIR


def _inspect_file(path: Path) -> list[str]:
    lines = [
        f"File: {path.name}",
        f"Path: {path}",
    ]
    try:
        table, separator = _read_for_inspection(path)
        separator_text = _format_separator(separator)
        lines.extend(
            [
                f"Detected separator: {separator_text}",
                f"Shape: {table.shape[0]} rows x {table.shape[1]} columns",
                "Columns:",
                ", ".join(str(column) for column in table.columns),
                "First 5 rows:",
                table.head(5).to_string(index=False),
            ]
        )
    except Exception as exc:
        lines.append(f"ERROR: {exc}")

    return lines


def _read_for_inspection(path: Path) -> tuple[pd.DataFrame, str]:
    lower_name = path.name.lower()
    if lower_name.endswith((".xlsx", ".xls")):
        return pd.read_excel(path), "excel"

    attempts = []
    errors = []
    for separator in ["\t", ",", ";"]:
        try:
            table = pd.read_csv(
                path,
                sep=separator,
                compression="infer",
                low_memory=False,
            )
            attempts.append((separator, table))
        except Exception as exc:
            errors.append(f"{_format_separator(separator)}: {exc}")

    if not attempts:
        raise ValueError(f"Could not parse file. Errors: {' | '.join(errors)}")

    separator, table = max(attempts, key=lambda item: item[1].shape[1])
    return table, separator


def _format_separator(separator: str) -> str:
    if separator == "\t":
        return "tab"
    if separator == ",":
        return "comma"
    if separator == ";":
        return "semicolon"

    return separator


if __name__ == "__main__":
    main()
