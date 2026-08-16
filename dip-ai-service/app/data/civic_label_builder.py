"""Build standardized external gene labels from CIViC nightly TSV files."""

from __future__ import annotations

from pathlib import Path
import re

import pandas as pd


GENE_SUMMARIES_PATTERN = "*GeneSummaries.tsv"
CLINICAL_EVIDENCE_PATTERN = "*ClinicalEvidenceSummaries.tsv"

# Specific gene-symbol columns come first. ``molecular_profile`` is preferred
# over ``variant_origin`` because CIViC clinical exports contain both, while
# variant_origin contains values such as "Somatic", not gene symbols.
GENE_COLUMN_CANDIDATES = [
    "gene",
    "genes",
    "gene_name",
    "gene_symbol",
    "symbol",
    "entrez_name",
    "entrez_symbol",
    "molecular_profile",
    "variant_origin",
]


def read_civic_tsv(path: Path) -> pd.DataFrame:
    """Read one CIViC TSV file with clear path and parse errors."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"CIViC TSV file not found: {path}")
    if not path.is_file():
        raise ValueError(f"CIViC TSV path is not a file: {path}")

    try:
        return pd.read_csv(path, sep="\t", low_memory=False)
    except Exception as exc:
        raise ValueError(f"Failed to read CIViC TSV file {path}: {exc}") from exc


def detect_civic_gene_column(df: pd.DataFrame) -> str:
    """
    Detect the most plausible gene-bearing column in a CIViC dataframe.

    Current GeneSummaries exports use ``name`` with ``feature_type=Gene``.
    ClinicalEvidenceSummaries exports use ``molecular_profile``.
    """
    normalized_columns = {
        str(column).strip().lower(): str(column) for column in df.columns
    }
    for candidate in GENE_COLUMN_CANDIDATES:
        if candidate in normalized_columns:
            return normalized_columns[candidate]

    # CIViC GeneSummaries uses "name", which is only safe when feature_type
    # explicitly identifies the records as genes.
    if "name" in normalized_columns and "feature_type" in normalized_columns:
        feature_type_column = normalized_columns["feature_type"]
        feature_types = (
            df[feature_type_column]
            .dropna()
            .astype(str)
            .str.strip()
            .str.lower()
        )
        if not feature_types.empty and feature_types.eq("gene").any():
            return normalized_columns["name"]

    gene_columns = [
        str(column)
        for column in df.columns
        if "gene" in str(column).strip().lower()
    ]
    if gene_columns:
        # Prefer populated name/symbol fields over IDs or empty fusion-partner
        # fields when several broad matches are available.
        return max(
            gene_columns,
            key=lambda column: (
                int(df[column].notna().sum()),
                int("name" in column.lower() or "symbol" in column.lower()),
                -list(df.columns).index(column),
            ),
        )

    raise ValueError(
        "No gene column found in CIViC dataframe. Checked direct candidates "
        f"{GENE_COLUMN_CANDIDATES} and columns containing 'gene'. "
        f"Available columns: {list(df.columns)}"
    )


def clean_gene_symbol(value) -> str:
    """Normalize a potential gene symbol while preserving later delimiters."""
    if pd.isna(value):
        return ""
    text = str(value).strip().upper()
    if text in {"", "NA", "N/A", "NAN", "NONE", "NULL"}:
        return ""
    return re.sub(r"\s+", " ", text)


def build_civic_external_labels(civic_dir: Path) -> pd.DataFrame:
    """
    Build positive CIViC gene labels from gene and clinical evidence exports.

    GeneSummaries is the main source. Clinical molecular profiles support genes
    by matching normalized GeneSummaries symbols within each profile.
    """
    civic_dir = Path(civic_dir)
    gene_path = _find_single_file(civic_dir, GENE_SUMMARIES_PATTERN)
    clinical_path = _find_optional_single_file(
        civic_dir,
        CLINICAL_EVIDENCE_PATTERN,
    )

    gene_summaries = read_civic_tsv(gene_path)
    gene_column = detect_civic_gene_column(gene_summaries)
    gene_symbols = _extract_gene_summary_symbols(
        gene_summaries,
        gene_column,
    )
    if not gene_symbols:
        raise ValueError(
            f"No usable gene symbols found in CIViC GeneSummaries column "
            f"'{gene_column}' from {gene_path}"
        )

    records = [
        {
            "gene_name": gene_name,
            "evidence_type": "civic_gene_summary",
            "evidence_score": 0.9,
        }
        for gene_name in gene_symbols
    ]

    if clinical_path is not None:
        clinical = read_civic_tsv(clinical_path)
        try:
            clinical_column = detect_civic_gene_column(clinical)
        except ValueError:
            clinical_column = None

        if clinical_column is not None:
            if clinical_column.strip().lower() == "molecular_profile":
                clinical_genes = _extract_profile_genes(
                    clinical[clinical_column],
                    reference_genes=set(gene_symbols),
                )
            else:
                clinical_genes = _extract_direct_gene_symbols(
                    clinical[clinical_column]
                )
            records.extend(
                {
                    "gene_name": gene_name,
                    "evidence_type": "civic_clinical_evidence",
                    "evidence_score": 1.0,
                }
                for gene_name in clinical_genes
            )

    evidence = pd.DataFrame(records)
    labels = (
        evidence.groupby("gene_name", as_index=False)
        .agg(
            evidence_type=(
                "evidence_type",
                lambda values: ";".join(sorted(set(values))),
            ),
            evidence_score=("evidence_score", "max"),
        )
        .sort_values("gene_name")
        .reset_index(drop=True)
    )
    labels.insert(1, "source", "CIViC")
    labels["label"] = 1
    return labels.loc[
        :,
        ["gene_name", "source", "evidence_type", "evidence_score", "label"],
    ]


def _find_single_file(directory: Path, pattern: str) -> Path:
    matches = sorted(directory.glob(pattern))
    if not matches:
        raise FileNotFoundError(
            f"No CIViC file matching '{pattern}' found in: {directory}"
        )
    if len(matches) > 1:
        raise ValueError(
            f"Multiple CIViC files match '{pattern}' in {directory}: {matches}"
        )
    return matches[0]


def _find_optional_single_file(
    directory: Path,
    pattern: str,
) -> Path | None:
    matches = sorted(directory.glob(pattern))
    if not matches:
        return None
    if len(matches) > 1:
        raise ValueError(
            f"Multiple CIViC files match '{pattern}' in {directory}: {matches}"
        )
    return matches[0]


def _extract_direct_gene_symbols(values: pd.Series) -> list[str]:
    gene_symbols = set()
    for value in values:
        cleaned = clean_gene_symbol(value)
        if not cleaned:
            continue
        for token in re.split(r"[,;|]", cleaned):
            symbol = token.strip()
            if _is_usable_gene_symbol(symbol):
                gene_symbols.add(symbol)
    return sorted(gene_symbols)


def _extract_gene_summary_symbols(
    gene_summaries: pd.DataFrame,
    gene_column: str,
) -> list[str]:
    if "feature_type" not in gene_summaries.columns:
        return _extract_direct_gene_symbols(gene_summaries[gene_column])

    feature_types = (
        gene_summaries["feature_type"]
        .astype("string")
        .str.strip()
        .str.lower()
    )
    gene_rows = gene_summaries.loc[feature_types.eq("gene")]
    gene_symbols = set(_extract_direct_gene_symbols(gene_rows[gene_column]))

    fusion_rows = gene_summaries.loc[feature_types.eq("fusion")]
    for partner_column in [
        "five_prime_gene_name",
        "three_prime_gene_name",
    ]:
        if partner_column in fusion_rows.columns:
            gene_symbols.update(
                _extract_direct_gene_symbols(fusion_rows[partner_column])
            )

    # Some CIViC fusions have a missing structured partner field. Recover known
    # partners from names such as EML4::ALK while dropping the placeholder "v".
    for fusion_name in fusion_rows[gene_column].dropna():
        cleaned = clean_gene_symbol(fusion_name)
        for partner in cleaned.split("::"):
            partner = partner.strip()
            if _is_usable_gene_symbol(partner):
                gene_symbols.add(partner)

    return sorted(gene_symbols)


def _is_usable_gene_symbol(symbol: str) -> bool:
    return bool(symbol) and symbol not in {
        "?",
        "-",
        "V",
        "VARIANT",
        "UNKNOWN",
        "UNSPECIFIED",
    }


def _extract_profile_genes(
    profiles: pd.Series,
    reference_genes: set[str],
) -> list[str]:
    if not reference_genes:
        return []

    # Longest-first alternation avoids a shorter symbol consuming the prefix of
    # a longer one. Boundaries permit CIViC fusion notation such as BCR::ABL1.
    alternatives = "|".join(
        re.escape(gene)
        for gene in sorted(reference_genes, key=lambda item: (-len(item), item))
    )
    pattern = re.compile(
        rf"(?<![A-Z0-9])(?:{alternatives})(?![A-Z0-9])",
        flags=re.IGNORECASE,
    )
    genes = set()
    for value in profiles.dropna():
        profile = clean_gene_symbol(value)
        if not profile:
            continue
        genes.update(match.upper() for match in pattern.findall(profile))
    return sorted(genes)
