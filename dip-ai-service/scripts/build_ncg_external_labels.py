from pathlib import Path
import sys


ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.core.config import OUTPUT_DIR
from app.data.ncg_label_builder import build_ncg_external_labels, find_ncg_files


REQUESTED_NCG_DIR = ROOT_DIR / "data" / "external" / "labels" / "ncg"
FALLBACK_NCG_DIR = ROOT_DIR / "data" / "external" / "labels"
OUTPUT_FILE = ROOT_DIR / "data" / "external" / "labels" / "external_targets_ncg.csv"
SUMMARY_FILE = OUTPUT_DIR / "reports" / "ncg_external_labels_summary.txt"


def main() -> None:
    """Build standardized positive external labels from NCG source files."""
    ncg_dir = _resolve_ncg_dir()
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_FILE.parent.mkdir(parents=True, exist_ok=True)

    labels = build_ncg_external_labels(ncg_dir)
    labels.to_csv(OUTPUT_FILE, index=False)

    files_used = find_ncg_files(ncg_dir)
    summary = _build_summary(ncg_dir, files_used, labels)
    SUMMARY_FILE.write_text(summary, encoding="utf-8")

    print(summary)
    print(f"Saved NCG external labels: {OUTPUT_FILE}")
    print(f"Saved summary: {SUMMARY_FILE}")


def _resolve_ncg_dir() -> Path:
    requested_files = find_ncg_files(REQUESTED_NCG_DIR)
    if requested_files:
        return REQUESTED_NCG_DIR

    return FALLBACK_NCG_DIR


def _build_summary(ncg_dir: Path, files_used: list[Path], labels) -> str:
    first_50 = labels["gene_name"].head(50).tolist() if "gene_name" in labels else []
    lines = [
        "NCG External Labels Summary",
        "===========================",
        f"Requested NCG directory: {REQUESTED_NCG_DIR}",
        f"Directory used: {ncg_dir}",
        "NCG files used:",
    ]
    if files_used:
        lines.extend(f"- {path}" for path in files_used)
    else:
        lines.append("- None")

    lines.extend(
        [
            f"Total positive genes: {len(labels)}",
            f"Output path: {OUTPUT_FILE}",
            "",
            "First 50 genes:",
            ", ".join(first_50) if first_50 else "None",
        ]
    )

    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
