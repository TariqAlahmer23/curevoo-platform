from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT_DIR))

from app.data.loaders import load_all_data
from app.data.validators import validate_all_data


def main():
    rna, mutations, clinical = load_all_data()

    validate_all_data(rna, mutations, clinical)

    print("Data validation successful.")
    print("RNA samples:", len([c for c in rna.columns if c != "gene_name"]))
    print("Mutation rows:", len(mutations))
    print("Clinical cases:", len(clinical))


if __name__ == "__main__":
    main()