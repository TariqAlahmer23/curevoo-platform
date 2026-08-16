"""Clinical recurrence label construction for supervised DIP-AI benchmarks."""

from __future__ import annotations

import numpy as np
import pandas as pd


CASE_ID_COLUMN = "case_id"
RECURRENCE_DAYS_COLUMN = "diagnoses.0.days_to_recurrence"
DISEASE_STATUS_COLUMN = "diagnoses.0.last_known_disease_status"

PATIENT_BARCODE_CANDIDATES = [
    "patient_barcode",
    "submitter_id",
    "cases.0.submitter_id",
    "bcr_patient_barcode",
]

POSITIVE_STATUS_PATTERN = (
    r"recurrence|recurrent|progression|progressive|persistent|persistence|tumor"
)
NEGATIVE_STATUS_PATTERN = (
    r"tumor\s*free|tumor-free|disease\s*free|disease-free|"
    r"free\s+of\s+tumor|no\s+evidence\s+of\s+disease"
)


def build_recurrence_labels(clinical: pd.DataFrame) -> pd.DataFrame:
    """
    Build non-circular recurrence/residual-disease labels from clinical fields.

    Label rules:
    - 1 if ``diagnoses.0.days_to_recurrence`` is present.
    - 1 if ``diagnoses.0.last_known_disease_status`` contains recurrence,
      progression, persistent, or tumor language.
    - 0 if ``diagnoses.0.last_known_disease_status`` contains tumor-free or
      disease-free language.
    - NaN otherwise, so the patient is excluded from supervised training.

    ``demographic.vital_status`` is intentionally not converted into a
    recurrence label because death is not equivalent to recurrence.
    """
    labels = pd.DataFrame(index=clinical.index)
    labels["case_id"] = (
        clinical[CASE_ID_COLUMN] if CASE_ID_COLUMN in clinical.columns else pd.NA
    )
    labels["patient_barcode"] = _derive_patient_barcode(clinical)
    labels["recurrence_label"] = np.nan

    if RECURRENCE_DAYS_COLUMN in clinical.columns:
        days_to_recurrence = pd.to_numeric(
            clinical[RECURRENCE_DAYS_COLUMN], errors="coerce"
        )
        labels.loc[days_to_recurrence.notna(), "recurrence_label"] = 1.0

    if DISEASE_STATUS_COLUMN in clinical.columns:
        disease_status = clinical[DISEASE_STATUS_COLUMN].astype("string").str.lower()
        negative_status = disease_status.str.contains(
            NEGATIVE_STATUS_PATTERN, case=False, na=False, regex=True
        )
        positive_status = disease_status.str.contains(
            POSITIVE_STATUS_PATTERN, case=False, na=False, regex=True
        ) & ~negative_status

        labels.loc[
            negative_status & labels["recurrence_label"].isna(), "recurrence_label"
        ] = 0.0
        labels.loc[positive_status, "recurrence_label"] = 1.0

    return labels.loc[:, ["case_id", "patient_barcode", "recurrence_label"]]


def _derive_patient_barcode(clinical: pd.DataFrame) -> pd.Series:
    for column in PATIENT_BARCODE_CANDIDATES:
        if column in clinical.columns:
            return clinical[column].apply(_normalize_patient_barcode)

    barcode_columns = [
        column for column in clinical.columns if "barcode" in column.lower()
    ]
    for column in barcode_columns:
        values = clinical[column].apply(_normalize_patient_barcode)
        if values.notna().any():
            return values

    return pd.Series(pd.NA, index=clinical.index, dtype="string")


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
