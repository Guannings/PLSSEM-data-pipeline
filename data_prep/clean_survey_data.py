"""
Clean raw questionnaire CSV exports and write analysis-ready files.

What this does for each raw file:
  1. Loads the raw CSV export.
  2. Drops trailing junk columns (anything named "Unnamed...").
  3. Drops fully duplicated respondent rows.
  4. Reports row/column counts before and after.
  5. Saves a cleaned copy as <name>_clean.csv (UTF-8 with BOM, so downstream
     tools handle non-ASCII headers correctly).

The folder is expected to contain raw files ending in "_raw.csv"
(e.g. the output of generate_synthetic_data.py).

Usage:
    python data_prep/clean_survey_data.py --folder synthetic_data
"""

import argparse
import os
import sys
import pandas as pd


def clean_one(src_path: str) -> None:
    folder = os.path.dirname(src_path)
    base = os.path.basename(src_path)
    out_name = base.replace("_raw.csv", "_clean.csv")
    if out_name == base:                       # raw file not following _raw.csv
        out_name = base.replace(".csv", "_clean.csv")
    out_path = os.path.join(folder, out_name)

    df = pd.read_csv(src_path, encoding="utf-8-sig")
    rows_before, cols_before = df.shape

    # 1. drop trailing junk columns
    junk_cols = [c for c in df.columns if str(c).startswith("Unnamed")]
    df = df.drop(columns=junk_cols)

    # 2. drop fully duplicated rows
    dup_count = int(df.duplicated().sum())
    df = df.drop_duplicates().reset_index(drop=True)

    rows_after, cols_after = df.shape

    # save UTF-8 with BOM for downstream Excel / SAS / SmartPLS compatibility
    df.to_csv(out_path, index=False, encoding="utf-8-sig")

    print(f"[{base}]")
    print(f"  rows    : {rows_before} -> {rows_after} "
          f"(removed {dup_count} duplicate rows)")
    print(f"  columns : {cols_before} -> {cols_after} "
          f"(removed {len(junk_cols)} junk columns)")
    print(f"  saved   : {out_name}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", default="synthetic_data",
                        help="folder containing the raw CSV files")
    args = parser.parse_args()

    if not os.path.isdir(args.folder):
        print(f"ERROR: folder not found: {args.folder}")
        return 1

    raw_files = sorted(f for f in os.listdir(args.folder)
                       if f.endswith("_raw.csv"))
    if not raw_files:
        print(f"No *_raw.csv files found in {args.folder}. "
              f"Run generate_synthetic_data.py first.")
        return 1

    print(f"Cleaning {len(raw_files)} file(s) in: {args.folder}\n")
    for f in raw_files:
        clean_one(os.path.join(args.folder, f))

    print("Done. Cleaned files are ready for the analysis step.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
