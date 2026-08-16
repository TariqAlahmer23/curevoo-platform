"""FastAPI application exposing the genomic target prioritization service.

Run locally with::

    python -m uvicorn app.api.app:app --host 127.0.0.1 --port 8001
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Annotated, AsyncIterator
import logging
import os

from fastapi import FastAPI, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import JSONResponse, PlainTextResponse

from app.api import prioritization_service as service
from app.schemas.prioritization import (
    AnalyzeResponse,
    HealthResponse,
    MetricsResponse,
)


SERVICE_NAME = "dip-ai-genomic-target-prioritization"
SERVICE_VERSION = "1.0.0"

# Guards the service against oversized uploads; the RNA expression matrices used
# by this project are large, so the ceiling is generous but still bounded.
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(512 * 1024 * 1024)))
UPLOAD_CHUNK_BYTES = 1024 * 1024

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Prepare report output directories before the service accepts traffic."""
    service.ensure_output_directories()
    yield


app = FastAPI(
    title="DIP-AI Genomic Target Prioritization",
    description=(
        "Research-use service that ranks candidate genomic targets in lung "
        "cancer from mutation and RNA expression evidence."
    ),
    version=SERVICE_VERSION,
    lifespan=lifespan,
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Log unexpected failures and return a generic error to the caller."""
    logger.exception("Unhandled error while serving %s", request.url.path)

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "The AI service failed to complete the request."},
    )


async def _persist_upload(upload: UploadFile, destination: Path) -> None:
    """
    Stream an upload to disk, rejecting files above the configured ceiling.

    Args:
        upload: Incoming multipart file.
        destination: Path the upload is written to.
    """
    written = 0

    with destination.open("wb") as target:
        while chunk := await upload.read(UPLOAD_CHUNK_BYTES):
            written += len(chunk)
            if written > MAX_UPLOAD_BYTES:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=(
                        f"Uploaded file exceeds the "
                        f"{MAX_UPLOAD_BYTES // (1024 * 1024)} MB limit."
                    ),
                )
            target.write(chunk)

    if written == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Uploaded file '{upload.filename}' is empty.",
        )


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Report service liveness and whether pipeline artifacts are available."""
    readiness = service.describe_readiness()
    is_ready = readiness["cohort_ranking_available"] and not readiness["missing_artifacts"]

    return HealthResponse(
        status="ok" if is_ready else "degraded",
        ok=is_ready,
        service=SERVICE_NAME,
        version=SERVICE_VERSION,
        metrics_available=readiness["metrics_available"],
        cohort_ranking_available=readiness["cohort_ranking_available"],
        missing_artifacts=readiness["missing_artifacts"],
    )


@app.get("/metrics", response_model=MetricsResponse)
def metrics() -> MetricsResponse:
    """Return the persisted model-evaluation metrics."""
    return MetricsResponse(ml_metrics=service.build_metrics_payload())


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    mutations_file: Annotated[UploadFile | None, File()] = None,
    expression_file: Annotated[UploadFile | None, File()] = None,
    top_n: Annotated[int, Query(ge=1, le=service.MAX_TOP_N)] = service.DEFAULT_TOP_N,
) -> AnalyzeResponse:
    """
    Run genomic target prioritization and return the research-use report.

    Supplying both a mutation CSV and an RNA expression CSV runs the full
    pipeline over them. Supplying neither reports the pre-computed reference
    cohort ranking.
    """
    with TemporaryDirectory(prefix="dip-ai-analyze-") as temp_dir:
        temp_path = Path(temp_dir)
        mutations_path: Path | None = None
        expression_path: Path | None = None

        if mutations_file is not None and mutations_file.filename:
            mutations_path = temp_path / "mutations.csv"
            await _persist_upload(mutations_file, mutations_path)

        if expression_file is not None and expression_file.filename:
            expression_path = temp_path / "expression.csv"
            await _persist_upload(expression_file, expression_path)

        try:
            payload = service.run_analysis(
                mutations_path=mutations_path,
                expression_path=expression_path,
                top_n=top_n,
            )
        except service.AnalysisInputError as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)
            ) from error
        except service.PipelineDataError as error:
            logger.error("Pipeline artifact unavailable: %s", error)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Required pipeline data is not available on the AI service.",
            ) from error

    return AnalyzeResponse(**payload)


@app.get("/results/{run_id}", response_model=AnalyzeResponse)
def results(run_id: str) -> AnalyzeResponse:
    """Return a previously generated analysis payload by run id."""
    payload = service.load_run_payload(run_id)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Analysis run not found."
        )

    return AnalyzeResponse(**payload)


@app.get("/reports/{run_id}", response_class=PlainTextResponse)
def report(run_id: str) -> PlainTextResponse:
    """Return the Markdown research report generated for one analysis run."""
    markdown = service.load_run_report(run_id)
    if markdown is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Analysis report not found."
        )

    return PlainTextResponse(markdown, media_type="text/markdown; charset=utf-8")
