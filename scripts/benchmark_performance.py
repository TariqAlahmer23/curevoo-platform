"""Latency benchmark for the genomic target prioritization stack.

Reports the median of N timed requests per endpoint. The median is used rather
than the mean so a single scheduling stall does not distort the figure.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import requests

SAMPLES = Path(
    "C:/Users/sexyl/OneDrive/Desktop/Full-Project/dip-ai-service/data/samples"
)


def timed(method: str, url: str, **kwargs) -> tuple[float, int]:
    """Issue one request and return its wall-clock duration in milliseconds."""
    start = time.perf_counter()
    response = requests.request(method, url, timeout=600, **kwargs)
    elapsed_ms = (time.perf_counter() - start) * 1000.0

    return elapsed_ms, response.status_code


def measure(label: str, method: str, url: str, runs: int, **kwargs) -> dict:
    """Run one endpoint `runs` times and summarise the timings."""
    timings: list[float] = []
    codes: set[int] = set()

    for _ in range(runs):
        # Files must be reopened for every attempt.
        call_kwargs = dict(kwargs)
        if "files_factory" in call_kwargs:
            call_kwargs["files"] = call_kwargs.pop("files_factory")()

        try:
            elapsed_ms, code = timed(method, url, **call_kwargs)
        except Exception as exc:  # noqa: BLE001 - reported, not swallowed
            return {"label": label, "error": str(exc)[:120], "runs": runs}

        timings.append(elapsed_ms)
        codes.add(code)

    return {
        "label": label,
        "runs": runs,
        "median_ms": round(statistics.median(timings), 1),
        "min_ms": round(min(timings), 1),
        "max_ms": round(max(timings), 1),
        "codes": sorted(codes),
    }


def upload_files():
    """Open the sample datasets for a multipart upload."""
    return {
        "mutations_file": open(SAMPLES / "sample_mutations.csv", "rb"),
        "expression_file": open(SAMPLES / "sample_rna_expression.csv", "rb"),
    }


def backend_upload_files():
    """Open the sample datasets using the backend's field names."""
    return {
        "mutationsFile": (
            "sample_mutations.csv",
            open(SAMPLES / "sample_mutations.csv", "rb"),
            "text/csv",
        ),
        "expressionFile": (
            "sample_rna_expression.csv",
            open(SAMPLES / "sample_rna_expression.csv", "rb"),
            "text/csv",
        ),
    }


def run_ai(base: str, runs: int, heavy_runs: int) -> list[dict]:
    """Benchmark the AI service endpoints directly."""
    results = [
        measure("GET /health", "GET", f"{base}/health", runs),
        measure("GET /metrics", "GET", f"{base}/metrics", runs),
        measure("POST /analyze (cohort)", "POST", f"{base}/analyze?top_n=20", runs),
    ]

    run_id = None
    try:
        payload = requests.post(f"{base}/analyze?top_n=5", timeout=600).json()
        run_id = payload.get("run_id")
    except Exception:  # noqa: BLE001
        pass

    if run_id:
        results.append(
            measure("GET /results/{id}", "GET", f"{base}/results/{run_id}", runs)
        )
        results.append(
            measure("GET /reports/{id}", "GET", f"{base}/reports/{run_id}", runs)
        )

    results.append(
        measure(
            "POST /analyze (uploaded files)",
            "POST",
            f"{base}/analyze?top_n=20",
            heavy_runs,
            files_factory=upload_files,
        )
    )

    return results


def run_backend(base: str, token: str, runs: int, heavy_runs: int) -> list[dict]:
    """Benchmark the backend endpoints that front the AI service."""
    api = f"{base}/api/ai/genomic-target-prioritization"
    headers = {"Authorization": f"Bearer {token}"}

    return [
        measure("GET /health (backend)", "GET", f"{base}/health", runs),
        measure("GET AI health proxy", "GET", f"{api}/health", runs, headers=headers),
        measure(
            "POST /analyze (cohort)",
            "POST",
            f"{api}/analyze",
            runs,
            headers=headers,
            data={"topN": "20"},
        ),
        measure(
            "POST /analyze (uploaded files)",
            "POST",
            f"{api}/analyze",
            heavy_runs,
            headers=headers,
            data={"topN": "20"},
            files_factory=backend_upload_files,
        ),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, choices=["ai", "backend"])
    parser.add_argument("--base", required=True)
    parser.add_argument("--token", default="")
    parser.add_argument("--runs", type=int, default=10)
    parser.add_argument("--heavy-runs", type=int, default=5)
    parser.add_argument("--warmup", action="store_true")
    args = parser.parse_args()

    if args.warmup:
        try:
            requests.get(f"{args.base}/health", timeout=600)
        except Exception:  # noqa: BLE001
            pass

    if args.target == "ai":
        results = run_ai(args.base, args.runs, args.heavy_runs)
    else:
        results = run_backend(args.base, args.token, args.runs, args.heavy_runs)

    print(json.dumps(results, indent=1))
    print()
    print(f"{'endpoint':<34}{'median':>10}{'min':>10}{'max':>10}  codes")
    for r in results:
        if "error" in r:
            print(f"{r['label']:<34}{'ERROR':>10}  {r['error']}")
            continue
        print(
            f"{r['label']:<34}{r['median_ms']:>9.1f}ms{r['min_ms']:>9.1f}ms"
            f"{r['max_ms']:>9.1f}ms  {r['codes']}"
        )


if __name__ == "__main__":
    sys.exit(main())
