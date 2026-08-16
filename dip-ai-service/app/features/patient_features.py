"""Patient-level supervised ML feature construction for DIP-AI."""

from __future__ import annotations

import pandas as pd

from app.models.ml_labels import build_recurrence_labels


IMPORTANT_GENES = [
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
    "SMARCA4",
    "ATM",
    "CDKN2A",
]

NONSYNONYMOUS_VARIANT_CLASSES = {
    "Missense_Mutation",
    "Nonsense_Mutation",
    "Frame_Shift_Del",
    "Frame_Shift_Ins",
    "Splice_Site",
    "Splice_Region",
    "Translation_Start_Site",
    "Nonstop_Mutation",
    "In_Frame_Del",
    "In_Frame_Ins",
}


def build_patient_level_features(
    mutations: pd.DataFrame, rna: pd.DataFrame, clinical: pd.DataFrame
) -> pd.DataFrame:
    """
    Build a patient-level supervised ML table for recurrence-risk benchmarking.

    The resulting dataframe uses mutation patients as the base cohort, merges
    RNA and clinical features, attaches recurrence labels, and excludes patients
    without non-circular recurrence labels.
    """
    mutation_features = _build_mutation_features(mutations)
    rna_features = _build_rna_expression_features(rna)
    clinical_features = _build_clinical_features(clinical)

    dataset = mutation_features.merge(rna_features, on="patient_barcode", how="left")
    dataset = dataset.merge(clinical_features, on="patient_barcode", how="left")

    for gene in IMPORTANT_GENES:
        mutation_column = f"{gene}_mutated"
        expression_column = f"{gene}_expression"
        if mutation_column not in dataset.columns:
            dataset[mutation_column] = 0
        if expression_column not in dataset.columns:
            dataset[expression_column] = pd.NA

    if "recurrence_label" not in dataset.columns:
        dataset["recurrence_label"] = pd.NA

    dataset = dataset.dropna(subset=["recurrence_label"]).reset_index(drop=True)
    dataset["recurrence_label"] = dataset["recurrence_label"].astype(int)

    ordered_columns = (
        ["case_id", "patient_barcode", "recurrence_label"]
        + [f"{gene}_mutated" for gene in IMPORTANT_GENES]
        + ["total_mutations", "nonsynonymous_mutations"]
        + [f"{gene}_expression" for gene in IMPORTANT_GENES]
        + ["age_at_diagnosis", "gender", "pathologic_stage"]
    )
    existing_ordered_columns = [
        column for column in ordered_columns if column in dataset.columns
    ]
    remaining_columns = [
        column for column in dataset.columns if column not in existing_ordered_columns
    ]

    return dataset.loc[:, existing_ordered_columns + remaining_columns]


def _build_mutation_features(mutations: pd.DataFrame) -> pd.DataFrame:
    required_columns = ["patient_barcode", "Hugo_Symbol"]
    missing_columns = [
        column for column in required_columns if column not in mutations.columns
    ]
    if missing_columns:
        raise ValueError(f"Mutation data missing required columns: {missing_columns}")

    work = mutations.copy()
    work["patient_barcode"] = work["patient_barcode"].apply(_normalize_patient_barcode)
    work["gene_name"] = work["Hugo_Symbol"].astype("string").str.upper().str.strip()
    work = work.dropna(subset=["patient_barcode"])
    work = work[work["patient_barcode"] != ""]

    patients = pd.DataFrame(
        {"patient_barcode": sorted(work["patient_barcode"].astype(str).unique())}
    )
    total_mutations = (
        work.groupby("patient_barcode").size().reset_index(name="total_mutations")
    )

    if "Variant_Classification" in work.columns:
        nonsynonymous = work[
            work["Variant_Classification"].isin(NONSYNONYMOUS_VARIANT_CLASSES)
        ]
    else:
        nonsynonymous = work.iloc[0:0]
    nonsynonymous_counts = (
        nonsynonymous.groupby("patient_barcode")
        .size()
        .reset_index(name="nonsynonymous_mutations")
    )

    important_mutations = work[work["gene_name"].isin(IMPORTANT_GENES)]
    if important_mutations.empty:
        gene_binary = pd.DataFrame({"patient_barcode": patients["patient_barcode"]})
    else:
        gene_binary = (
            important_mutations.assign(mutated=1)
            .pivot_table(
                index="patient_barcode",
                columns="gene_name",
                values="mutated",
                aggfunc="max",
                fill_value=0,
            )
            .reset_index()
        )
        gene_binary.columns.name = None

    features = patients.merge(total_mutations, on="patient_barcode", how="left")
    features = features.merge(nonsynonymous_counts, on="patient_barcode", how="left")
    features = features.merge(gene_binary, on="patient_barcode", how="left")

    features["total_mutations"] = features["total_mutations"].fillna(0).astype(int)
    features["nonsynonymous_mutations"] = (
        features["nonsynonymous_mutations"].fillna(0).astype(int)
    )

    for gene in IMPORTANT_GENES:
        if gene not in features.columns:
            features[gene] = 0
        features[gene] = features[gene].fillna(0).astype(int)

    rename_map = {gene: f"{gene}_mutated" for gene in IMPORTANT_GENES}
    return features.rename(columns=rename_map)


def _build_rna_expression_features(rna: pd.DataFrame) -> pd.DataFrame:
    if "gene_name" not in rna.columns:
        return pd.DataFrame(columns=["patient_barcode"])

    sample_columns = [column for column in rna.columns if column != "gene_name"]
    if not sample_columns:
        return pd.DataFrame(columns=["patient_barcode"])

    work = rna.copy()
    work["gene_name"] = work["gene_name"].astype("string").str.upper().str.strip()
    work = work[work["gene_name"].isin(IMPORTANT_GENES)]
    if work.empty:
        return pd.DataFrame(columns=["patient_barcode"])

    expression_matrix = work.set_index("gene_name").loc[:, sample_columns]
    expression_matrix = expression_matrix.apply(pd.to_numeric, errors="coerce")
    expression_matrix = expression_matrix.groupby(level=0).mean()

    patient_expression = expression_matrix.T
    patient_expression["patient_barcode"] = [
        _normalize_patient_barcode(column) for column in patient_expression.index
    ]
    patient_expression = patient_expression.dropna(subset=["patient_barcode"])
    patient_expression = patient_expression.groupby("patient_barcode").mean()

    patient_expression = patient_expression.rename(
        columns={gene: f"{gene}_expression" for gene in patient_expression.columns}
    )
    patient_expression = patient_expression.reset_index()

    for gene in IMPORTANT_GENES:
        column = f"{gene}_expression"
        if column not in patient_expression.columns:
            patient_expression[column] = pd.NA

    return patient_expression.loc[
        :, ["patient_barcode"] + [f"{gene}_expression" for gene in IMPORTANT_GENES]
    ]


def _build_clinical_features(clinical: pd.DataFrame) -> pd.DataFrame:
    labels = build_recurrence_labels(clinical)
    features = labels.copy()

    if "diagnoses.0.age_at_diagnosis" in clinical.columns:
        age = pd.to_numeric(clinical["diagnoses.0.age_at_diagnosis"], errors="coerce")
        if age.dropna().median() > 365:
            age = age / 365.25
        features["age_at_diagnosis"] = age
    else:
        features["age_at_diagnosis"] = pd.NA

    if "demographic.gender" in clinical.columns:
        features["gender"] = (
            clinical["demographic.gender"].astype("string").str.lower().str.strip()
        )
    else:
        features["gender"] = pd.NA

    if "diagnoses.0.ajcc_pathologic_stage" in clinical.columns:
        features["pathologic_stage"] = (
            clinical["diagnoses.0.ajcc_pathologic_stage"]
            .astype("string")
            .str.strip()
        )
    else:
        features["pathologic_stage"] = pd.NA

    features = features.dropna(subset=["patient_barcode"])
    return features.drop_duplicates(subset=["patient_barcode"], keep="first")


def _normalize_patient_barcode(value: object) -> object:
    if pd.isna(value):
        return pd.NA

    text = str(value).strip()
    if not text:
        return pd.NA

    text = text.split(".")[0]
    if text.upper().startswith("TCGA-") and len(text) >= 12:
        return text[:12].upper()

    return text
