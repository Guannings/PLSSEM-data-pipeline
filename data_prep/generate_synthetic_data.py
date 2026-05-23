"""
Generate synthetic survey data for the PLS-SEM pipeline.

No real survey responses are distributed with this repository. This script
fabricates data with the SAME STRUCTURE as the original questionnaires so the
rest of the pipeline (cleaning, PLS-SEM, figures) can be run and inspected.

The fabricated data is purely random/simulated. It is generated so that:
  * items within a construct are correlated  -> realistic outer loadings
  * constructs are correlated along TPB paths -> non-trivial structural paths
so the downstream scripts produce sensible-looking (but meaningless) output.

Output: two "raw" CSV files written to ./synthetic_data/ (git-ignored), each
deliberately including a couple of junk columns and duplicate rows so that
clean_survey_data.py has something to remove.

Usage:
    python data_prep/generate_synthetic_data.py
    python data_prep/generate_synthetic_data.py --n 800 --out synthetic_data
"""

import argparse
import os
import numpy as np
import pandas as pd

# Indicator counts per construct (matches the expected data schema)
CONSTRUCTS = {"AT": 12, "SN": 12, "PBC": 12, "BI": 12, "E": 13}

# Demographic columns: name -> list of valid category codes
DEMOGRAPHICS = {
    "City":      [1, 2],
    "District":  list(range(1, 30)),
    "Gender":    [1, 2],
    "Education": [1, 2, 3, 4],
    "Age":       [1, 2, 3, 4, 5, 6],
    "Income":    [1, 2, 3, 4, 5, 6],
    "Res_Year":  [1, 2, 3, 4, 5],
    "Member_12": [1, 2],
    "Member_65": [1, 2],
}


def likert_from_latent(latent, rng, noise=0.9):
    """Turn a continuous latent score into a 1-5 Likert response."""
    raw = latent + rng.normal(0, noise, size=latent.shape)
    # map roughly N(0,1)-ish values onto 1..5
    scaled = np.clip(np.round(raw + 3), 1, 5)
    return scaled.astype(int)


def make_dataset(n, rng):
    """Build one synthetic respondent-level dataset."""
    # --- latent construct scores with TPB-style dependencies --------
    at = rng.normal(0, 1, n)
    sn = rng.normal(0, 1, n)
    e  = rng.normal(0, 1, n)
    pbc = 0.45 * at + 0.35 * sn + 0.20 * e + rng.normal(0, 0.7, n)
    bi  = 0.20 * at + 0.20 * sn + 0.45 * pbc + 0.15 * e + rng.normal(0, 0.7, n)
    latent = {"AT": at, "SN": sn, "PBC": pbc, "BI": bi, "E": e}

    cols = {}
    # --- indicator columns -----------------------------------------
    for con, k in CONSTRUCTS.items():
        for i in range(1, k + 1):
            cols[f"{con}{i}"] = likert_from_latent(latent[con], rng)

    # --- demographic columns ---------------------------------------
    for name, codes in DEMOGRAPHICS.items():
        cols[name] = rng.choice(codes, size=n)

    df = pd.DataFrame(cols)

    # --- inject junk the cleaning step is meant to remove ----------
    df["Unnamed: 0"] = ""          # trailing empty export column
    df["Unnamed: 99"] = np.nan     # another junk column
    # duplicate a few rows
    dup = df.sample(n=max(3, n // 100), random_state=int(rng.integers(1e6)))
    df = pd.concat([df, dup], ignore_index=True)
    return df


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=600,
                        help="approximate respondents per dataset (default 600)")
    parser.add_argument("--out", default="synthetic_data",
                        help="output folder (default: ./synthetic_data)")
    parser.add_argument("--seed", type=int, default=42, help="random seed")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    for name in ("survey_a_raw.csv", "survey_b_raw.csv"):
        df = make_dataset(args.n, rng)
        path = os.path.join(args.out, name)
        df.to_csv(path, index=False, encoding="utf-8-sig")
        print(f"wrote {path}  ({len(df)} rows incl. duplicates, {df.shape[1]} cols)")

    print("\nSynthetic data is fabricated and meaningless — for running the "
          "pipeline only.\nNext: python data_prep/clean_survey_data.py --folder "
          + args.out)


if __name__ == "__main__":
    main()
