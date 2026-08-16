"""Build standardized external labels from Network of Cancer Genes files."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


SUPPORTED_EXTENSIONS = {
    ".csv",
    ".tsv",
    ".txt",
    ".xlsx",
    ".xls",
    ".gz",
}

GENE_COLUMN_CANDIDATES = [
    "gene",
    "gene_name",
    "symbol",
    "gene_symbol",
    "hugo_symbol",
    "entrez_symbol",
    "Gene",
    "Symbol",
    "HUGO symbol",
]

TIME_IMMUNE_PATTERN = (
    "time",
    "immune",
    "immun",
    "microenvironment",
    "tme",
)


def find_ncg_files(ncg_dir: Path) -> list[Path]:
    """Find supported NCG source tables in a directory."""
    if not ncg_dir.exists():
        return []

    files = []
    include_all_supported = ncg_dir.name.lower() == "ncg"
    for path in sorted(ncg_dir.iterdir()):
        if not path.is_file():
            continue
        if not _is_supported_table(path):
            continue
        if path.name.lower().startswith("external_targets"):
            continue
        if include_all_supported or "ncg" in path.name.lower():
            files.append(path)

    return files


def read_table_flexibly(path: Path) -> pd.DataFrame:
    """
    Read CSV/TSV/TXT/XLS/XLSX/GZ tables with conservative separator detection.

    Text-like files try tab first, then comma, then semicolon. Gzip files are
    handled through pandas' compression inference.
    """
    if not path.exists():
        raise FileNotFoundError(f"NCG file not found: {path}")

    lower_name = path.name.lower()
    if lower_name.endswith((".xlsx", ".xls")):
        return pd.read_excel(path)

    attempts: list[tuple[str, pd.DataFrame]] = []
    errors: list[str] = []
    for separator in ["\t", ",", ";"]:
        try:
            table = pd.read_csv(
                path,
                sep=separator,
                compression="infer",
                low_memory=False,
            )
            attempts.append((separator, table))
        except Exception as exc:  # pragma: no cover - defensive parser fallback
            errors.append(f"separator {repr(separator)} failed: {exc}")

    if not attempts:
        raise ValueError(f"Could not read {path}. Parser errors: {' | '.join(errors)}")

    _, best_table = max(attempts, key=lambda item: item[1].shape[1])
    return best_table


def detect_gene_column(df: pd.DataFrame) -> str:
    """Detect the gene-symbol column in an NCG table."""
    normalized_columns = {_normalize_column_name(column): column for column in df.columns}
    for candidate in GENE_COLUMN_CANDIDATES:
        normalized_candidate = _normalize_column_name(candidate)
        if normalized_candidate in normalized_columns:
            return normalized_columns[normalized_candidate]

    raise ValueError(
        "Could not detect gene column. Available columns: "
        f"{', '.join(str(column) for column in df.columns)}"
    )


def build_ncg_external_labels(ncg_dir: Path) -> pd.DataFrame:
    """
    Convert all NCG source files in a directory into standardized positive labels.

    Returns columns:
    ``gene_name, source, evidence_type, evidence_score, label``.
    """
    ncg_files = find_ncg_files(ncg_dir)
    label_tables = []
    for path in ncg_files:
        table = read_table_flexibly(path)
        gene_column = detect_gene_column(table)
        evidence_type = _infer_evidence_type(path, table)
        work = pd.DataFrame(
            {
                "gene_name": table[gene_column].apply(_clean_gene_name),
                "source": "NCG",
                "evidence_type": evidence_type,
                "evidence_score": 1.0,
                "label": 1,
            }
        )
        work = work.dropna(subset=["gene_name"])
        work = work[work["gene_name"] != ""]
        label_tables.append(work)

    if not label_tables:
        return pd.DataFrame(
            columns=[
                "gene_name",
                "source",
                "evidence_type",
                "evidence_score",
                "label",
            ]
        )

    labels = pd.concat(label_tables, ignore_index=True)
    labels = (
        labels.groupby("gene_name", as_index=False)
        .agg(
            source=("source", _join_unique_values),
            evidence_type=("evidence_type", _join_unique_values),
            evidence_score=("evidence_score", "max"),
            label=("label", "max"),
        )
        .sort_values("gene_name")
        .reset_index(drop=True)
    )
    labels["label"] = labels["label"].astype(int)

    return labels


def _is_supported_table(path: Path) -> bool:
    suffixes = [suffix.lower() for suffix in path.suffixes]
    return any(suffix in SUPPORTED_EXTENSIONS for suffix in suffixes)


def _normalize_column_name(column: object) -> str:
    return (
        str(column)
        .strip()
        .lower()
        .replace(" ", "_")
        .replace("-", "_")
    )


def _clean_gene_name(value: object) -> object:
    if pd.isna(value):
        return pd.NA

    text = str(value).strip().upper()
    if not text or text in {"NAN", "NA", "NONE", "NULL"}:
        return pd.NA

    return text


def _infer_evidence_type(path: Path, table: pd.DataFrame) -> pd.Series:
    row_count = len(table)
    lower_name = path.name.lower()
    time_like_columns = [
        column
        for column in table.columns
        if any(pattern in str(column).lower() for pattern in TIME_IMMUNE_PATTERN)
    ]

    if any(pattern in lower_name for pattern in TIME_IMMUNE_PATTERN):
        return pd.Series(["TIME_or_immune_driver"] * row_count, index=table.index)

    if not time_like_columns:
        return pd.Series(["cancer_driver"] * row_count, index=table.index)

    time_like_values = table.loc[:, time_like_columns]
    has_time_like_evidence = time_like_values.apply(
        lambda row: any(_is_truthy_evidence_value(value) for value in row),
        axis=1,
    )

    return pd.Series(
        [
            "TIME_or_immune_driver" if has_evidence else "cancer_driver"
            for has_evidence in has_time_like_evidence
        ],
        index=table.index,
    )


def _is_truthy_evidence_value(value: object) -> bool:
    if pd.isna(value):
        return False

    text = str(value).strip().lower()
    return text not in {"", "0", "0.0", "false", "no", "none", "nan"}


def _join_unique_values(values: pd.Series) -> str:
    unique_values = sorted(
        str(value).strip()
        for value in values.dropna().unique()
        if str(value).strip()
    )
    return ";".join(unique_values)
