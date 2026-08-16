"""Mutation-level feature engineering for target candidate scoring."""

import pandas as pd


NONSYNONYMOUS_VARIANT_CLASSES = {
    "Missense_Mutation",
    "Frame_Shift_Del",
    "Frame_Shift_Ins",
    "Nonsense_Mutation",
    "Nonstop_Mutation",
    "Translation_Start_Site",
    "Splice_Site",
    "In_Frame_Del",
    "In_Frame_Ins",
}


def build_mutation_features(mutations: pd.DataFrame) -> pd.DataFrame:
    """
    Build gene-level mutation features from a cleaned mutation table.

    Args:
        mutations: Mutation dataframe with gene, patient, sample, and variant
            classification columns.

    Returns:
        Dataframe with one row per gene and mutation-derived feature columns.
    """
    required_columns = [
        "Hugo_Symbol",
        "patient_barcode",
        "sample_barcode",
        "Variant_Classification",
    ]
    missing_columns = [col for col in required_columns if col not in mutations.columns]
    if missing_columns:
        raise ValueError(f"Mutation dataframe missing required columns: {missing_columns}")

    clean_mutations = mutations.dropna(subset=["Hugo_Symbol"]).copy()
    clean_mutations["Variant_Classification"] = clean_mutations[
        "Variant_Classification"
    ].fillna("")

    grouped = clean_mutations.groupby("Hugo_Symbol", dropna=False)

    features = grouped.agg(
        mutation_count=("Hugo_Symbol", "size"),
        mutated_patients=("patient_barcode", "nunique"),
        mutated_samples=("sample_barcode", "nunique"),
    )

    variant_counts = grouped["Variant_Classification"].agg(
        nonsynonymous_mutation_count=lambda values: values.isin(
            NONSYNONYMOUS_VARIANT_CLASSES
        ).sum(),
        missense_count=lambda values: values.eq("Missense_Mutation").sum(),
        frameshift_count=lambda values: values.isin(
            {"Frame_Shift_Del", "Frame_Shift_Ins"}
        ).sum(),
        nonsense_count=lambda values: values.isin(
            {"Nonsense_Mutation", "Nonstop_Mutation", "Translation_Start_Site"}
        ).sum(),
    )

    return (
        features.join(variant_counts)
        .reset_index()
        .rename(columns={"Hugo_Symbol": "gene_name"})
        .sort_values("mutation_count", ascending=False)
        .reset_index(drop=True)
    )
