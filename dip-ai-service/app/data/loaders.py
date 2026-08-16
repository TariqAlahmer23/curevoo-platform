import pandas as pd
from pathlib import Path

from app.core.config import RNA_FILE, MUTATIONS_FILE, CLINICAL_FILE


def load_csv(path: Path) -> pd.DataFrame:
    """
    Load CSV file safely.
    """
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    return pd.read_csv(path, low_memory=False)


def load_rna_expression() -> pd.DataFrame:
    """
    Load mapped RNA expression matrix.
    """
    return load_csv(RNA_FILE)


def load_mutations() -> pd.DataFrame:
    """
    Load cleaned mutation table.
    """
    return load_csv(MUTATIONS_FILE)


def load_clinical() -> pd.DataFrame:
    """
    Load clinical data.
    """
    return load_csv(CLINICAL_FILE)


def load_all_data():
    """
    Load all core DIP-AI datasets.
    """
    rna = load_rna_expression()
    mutations = load_mutations()
    clinical = load_clinical()

    return rna, mutations, clinical