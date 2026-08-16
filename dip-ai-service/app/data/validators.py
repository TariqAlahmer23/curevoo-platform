def validate_rna_expression(rna):
    required_columns = ["gene_name"]

    missing = [col for col in required_columns if col not in rna.columns]
    if missing:
        raise ValueError(f"RNA file missing required columns: {missing}")

    sample_columns = [c for c in rna.columns if c != "gene_name"]

    if len(sample_columns) == 0:
        raise ValueError("RNA file has no sample columns.")

    if rna["gene_name"].isna().any():
        raise ValueError("RNA file contains missing gene names.")

    return True


def validate_mutations(mutations):
    required_columns = [
        "Hugo_Symbol",
        "Tumor_Sample_Barcode",
        "patient_barcode",
        "sample_barcode"
    ]

    missing = [col for col in required_columns if col not in mutations.columns]
    if missing:
        raise ValueError(f"Mutation file missing required columns: {missing}")

    if mutations["Hugo_Symbol"].isna().all():
        raise ValueError("Mutation file has no valid gene symbols.")

    return True


def validate_clinical(clinical):
    required_columns = ["case_id"]

    missing = [col for col in required_columns if col not in clinical.columns]
    if missing:
        raise ValueError(f"Clinical file missing required columns: {missing}")

    if clinical["case_id"].isna().all():
        raise ValueError("Clinical file has no valid case IDs.")

    return True


def validate_all_data(rna, mutations, clinical):
    validate_rna_expression(rna)
    validate_mutations(mutations)
    validate_clinical(clinical)

    return True