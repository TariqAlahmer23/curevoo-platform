from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.data.loaders import load_all_data


def main():
    rna, mutations, clinical = load_all_data()

    print("RNA shape:", rna.shape)
    print("Mutations shape:", mutations.shape)
    print("Clinical shape:", clinical.shape)

    print("\nRNA columns sample:")
    print(rna.columns[:5].tolist())

    print("\nMutation columns:")
    print(mutations.columns.tolist())

    print("\nClinical columns sample:")
    print(clinical.columns[:10].tolist())

    print("\nData loading successful.")


if __name__ == "__main__":
    main()