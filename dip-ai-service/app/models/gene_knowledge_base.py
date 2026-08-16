"""Curated gene knowledge used by the DIP-AI target ranking engine."""

LUAD_NSCLC_RELEVANT_GENES = {
    "TP53",
    "KRAS",
    "EGFR",
    "KEAP1",
    "STK11",
    "BRAF",
    "ALK",
    "MET",
    "ERBB2",
    "RET",
    "ROS1",
    "NRAS",
    "PIK3CA",
    "MAP2K1",
    "NFE2L2",
    "RBM10",
    "SMARCA4",
    "ARID1A",
    "SETD2",
    "ATM",
    "CDKN2A",
    "CTNNB1",
}

PASSENGER_LIKE_HIGH_BACKGROUND_GENES = {
    "TTN",
    "MUC16",
    "RYR2",
    "CSMD3",
    "LRP1B",
    "USH2A",
    "ZFHX4",
    "FLG",
    "XIRP2",
    "FAT3",
    "PCDH15",
    "MUC17",
    "ANK2",
    "AHNAK",
    "AHNAK2",
}

CLINICALLY_ACTIONABLE_TARGETABLE_GENES = {
    "EGFR",
    "ALK",
    "ROS1",
    "BRAF",
    "MET",
    "RET",
    "ERBB2",
    "KRAS",
    "NTRK1",
    "NTRK2",
    "NTRK3",
}

DORMANCY_RESIDUAL_DISEASE_GENES = {
    "AXL",
    "ZEB1",
    "VIM",
    "SOX2",
    "CD44",
    "ITGB1",
    "TGFB1",
    "VEGFA",
    "HIF1A",
    "STAT3",
    "FN1",
    "POSTN",
}


def _normalize_gene_name(gene_name: str) -> str:
    """Normalize a gene symbol for matching against curated gene sets."""
    if gene_name is None:
        return ""

    return str(gene_name).strip().upper()


def get_luad_relevance_score(gene_name: str) -> float:
    """
    Score whether a gene has curated LUAD/NSCLC relevance.

    Returns:
        ``1.0`` for curated LUAD/NSCLC genes and ``0.2`` otherwise.
    """
    return 1.0 if _normalize_gene_name(gene_name) in LUAD_NSCLC_RELEVANT_GENES else 0.2


def get_passenger_penalty(gene_name: str) -> float:
    """
    Return the passenger-like/high-background mutation penalty for a gene.

    Returns:
        ``0.35`` for curated passenger-like genes and ``0.0`` otherwise.
    """
    return (
        0.35
        if _normalize_gene_name(gene_name) in PASSENGER_LIKE_HIGH_BACKGROUND_GENES
        else 0.0
    )


def get_targetability_score(gene_name: str) -> float:
    """
    Score whether a gene is clinically actionable or targetable.

    Returns:
        ``1.0`` for curated targetable genes and ``0.2`` otherwise.
    """
    return (
        1.0
        if _normalize_gene_name(gene_name) in CLINICALLY_ACTIONABLE_TARGETABLE_GENES
        else 0.2
    )


def get_dormancy_evidence_score(gene_name: str) -> float:
    """
    Score exploratory dormancy or residual disease evidence for a gene.

    Returns:
        ``1.0`` for curated exploratory dormancy genes and ``0.2`` otherwise.
    """
    return (
        1.0
        if _normalize_gene_name(gene_name) in DORMANCY_RESIDUAL_DISEASE_GENES
        else 0.2
    )
