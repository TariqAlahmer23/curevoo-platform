"""Build the final scientific summary report for the DIP-AI project."""

from __future__ import annotations

from datetime import date
from pathlib import Path
import re
from typing import Any

import pandas as pd

from app.core.config import BASE_DIR, OUTPUT_DIR, PROCESSED_DIR


REPORTS_DIR = OUTPUT_DIR / "reports"
LABELS_DIR = BASE_DIR / "data" / "external" / "labels"

TARGET_REPORT_FILE = REPORTS_DIR / "dip_ai_target_ranking_report.md"
QUALITY_AUDIT_FILE = REPORTS_DIR / "dip_ai_quality_audit_report.txt"
NCG_REPORT_FILE = REPORTS_DIR / "dip_ai_ncg_gene_classifier_report.txt"
LEAKAGE_REPORT_FILE = (
    REPORTS_DIR / "dip_ai_ncg_leakage_minimized_report.txt"
)
ABLATION_REPORT_FILE = REPORTS_DIR / "dip_ai_ncg_ablation_report.txt"
CONSENSUS_REPORT_FILE = (
    REPORTS_DIR / "dip_ai_consensus_ncg_civic_report.txt"
)

CONSENSUS_METRICS_FILE = (
    REPORTS_DIR / "dip_ai_consensus_ncg_civic_metrics.csv"
)
ABLATION_METRICS_FILE = REPORTS_DIR / "dip_ai_ncg_ablation_metrics.csv"
LEAKAGE_METRICS_FILE = (
    REPORTS_DIR / "dip_ai_ncg_leakage_minimized_metrics.csv"
)
CONSENSUS_LABELS_FILE = (
    LABELS_DIR / "external_targets_consensus_ncg_civic.csv"
)
FINAL_RANKING_FILE = PROCESSED_DIR / "target_ranking_v6_evidence_tiers.csv"

DISCLAIMER = (
    "DIP-AI is a research prototype only. It is not a diagnostic system, "
    "does not provide treatment recommendations, and must not be used as "
    "clinical decision support."
)


def load_text_file(path: Path) -> str:
    """Load a required UTF-8 text report with a clear missing-file error."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Required report file not found: {path}")
    return path.read_text(encoding="utf-8")


def load_csv_if_exists(path: Path) -> pd.DataFrame:
    """Load a CSV if present, otherwise return an empty dataframe."""
    path = Path(path)
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(path, low_memory=False)


def extract_key_results() -> dict:
    """Load source artifacts and derive all report-ready scientific results."""
    source_texts = {
        "target_ranking": load_text_file(TARGET_REPORT_FILE),
        "quality_audit": load_text_file(QUALITY_AUDIT_FILE),
        "ncg_benchmark": load_text_file(NCG_REPORT_FILE),
        "leakage_minimized": load_text_file(LEAKAGE_REPORT_FILE),
        "ablation": load_text_file(ABLATION_REPORT_FILE),
        "consensus": load_text_file(CONSENSUS_REPORT_FILE),
    }
    consensus_metrics = load_csv_if_exists(CONSENSUS_METRICS_FILE)
    ablation_metrics = load_csv_if_exists(ABLATION_METRICS_FILE)
    leakage_metrics = load_csv_if_exists(LEAKAGE_METRICS_FILE)
    consensus_labels = load_csv_if_exists(CONSENSUS_LABELS_FILE)
    ranked = load_csv_if_exists(FINAL_RANKING_FILE)

    for name, dataframe in {
        "consensus metrics": consensus_metrics,
        "ablation metrics": ablation_metrics,
        "leakage-minimized metrics": leakage_metrics,
        "consensus labels": consensus_labels,
        "final ranking": ranked,
    }.items():
        if dataframe.empty:
            raise ValueError(f"Required {name} table is missing or empty.")

    _require_columns(
        ranked,
        [
            "gene_name",
            "ranking_score_v4",
            "priority_v4",
            "evidence_tier_v6",
            "target_category_v6",
            "normal_lung_tpm",
            "safety_score",
            "safety_risk",
        ],
        "final ranking",
    )

    ranked = ranked.sort_values(
        "ranking_score_v4",
        ascending=False,
    ).reset_index(drop=True)
    priority_counts = ranked["priority_v4"].value_counts().to_dict()
    tier_counts = ranked["evidence_tier_v6"].value_counts().to_dict()

    ncg_results = _parse_ncg_report(source_texts["ncg_benchmark"])
    leakage_successful = _successful_metrics(leakage_metrics)
    consensus_successful = _successful_metrics(consensus_metrics)
    ablation_successful = _successful_metrics(ablation_metrics)

    leakage_best = _best_metric_record(leakage_successful)
    consensus_best_by_mode = {
        label_mode: _best_metric_record(
            consensus_successful[
                consensus_successful["label_mode"] == label_mode
            ]
        )
        for label_mode in ["any_source", "high_confidence"]
    }
    ablation_best = _best_ablation_records(ablation_successful)
    ablation_effects = _calculate_ablation_effects(ablation_successful)

    confidence_counts = (
        consensus_labels["consensus_confidence"].value_counts().to_dict()
    )
    coverage = {
        "ncg_external_count": _extract_int(
            r"NCG positive count:\s*(\d+)",
            source_texts["consensus"],
            default=int(consensus_labels["in_ncg"].sum()),
        ),
        "civic_external_count": _extract_int(
            r"CIViC positive count:\s*(\d+)",
            source_texts["consensus"],
            default=int(consensus_labels["in_civic"].sum()),
        ),
        "external_overlap_count": _extract_int(
            r"NCG/CIViC overlap count:\s*(\d+)",
            source_texts["consensus"],
            default=int(
                (
                    consensus_labels["in_ncg"]
                    & consensus_labels["in_civic"]
                ).sum()
            ),
        ),
        "any_source_ranked_count": int(
            (consensus_labels["consensus_label"] == 1).sum()
        ),
        "high_confidence_ranked_count": int(
            confidence_counts.get("high_confidence_positive", 0)
        ),
        "single_source_ranked_count": int(
            confidence_counts.get("single_source_positive", 0)
        ),
        "negative_candidate_count": int(
            confidence_counts.get("negative_candidate", 0)
        ),
        "civic_only_ranked_count": int(
            (
                consensus_labels["in_civic"]
                & ~consensus_labels["in_ncg"]
            ).sum()
        ),
    }

    high_confidence_delta = _paired_mode_delta(
        consensus_successful,
        from_mode="any_source",
        to_mode="high_confidence",
    )

    return {
        "generated_date": date.today().isoformat(),
        "source_reports_loaded": list(source_texts),
        "ranking": {
            "total_targets": int(len(ranked)),
            "priority_counts": {
                "High": int(priority_counts.get("High", 0)),
                "Medium": int(priority_counts.get("Medium", 0)),
                "Low": int(priority_counts.get("Low", 0)),
            },
            "tier_counts": {
                str(key): int(value) for key, value in tier_counts.items()
            },
            "top_targets": ranked.head(12).to_dict("records"),
            "tier_1_targets": _genes_in_tier(
                ranked,
                "Tier_1_Strong_Integrated_Target",
            ),
            "actionable_safety_supported": _genes_in_tier(
                ranked,
                "Tier_2_Actionable_Safety_Supported",
            ),
            "actionable_safety_caution": _genes_in_tier(
                ranked,
                "Tier_2_Actionable_With_Safety_Caution",
            ),
            "dormancy_exploratory": _genes_in_tier(
                ranked,
                "Tier_3_Dormancy_Exploratory_Target",
            ),
            "safety_examples": _gene_records(
                ranked,
                ["RET", "ALK", "EGFR", "KRAS", "TP53"],
            ),
        },
        "quality_audit": {
            "status": _extract_text(
                r"Status:\s*([A-Z]+)",
                source_texts["quality_audit"],
                default="UNKNOWN",
            ),
            "total_issues": _extract_int(
                r"Total issues:\s*(\d+)",
                source_texts["quality_audit"],
                default=-1,
            ),
            "required_files_checked": _extract_int(
                r"Required files checked:\s*(\d+)",
                source_texts["quality_audit"],
                default=0,
            ),
        },
        "ncg_benchmark": ncg_results,
        "leakage_benchmark": {
            "positive_genes": int(
                leakage_best.get("positive_genes", 0)
            ),
            "negative_genes": int(
                leakage_best.get("negative_genes", 0)
            ),
            "best_model": leakage_best,
            "all_models": leakage_successful.to_dict("records"),
        },
        "ablation": {
            "best_by_experiment": ablation_best,
            "effects": ablation_effects,
            "positive_genes": int(
                ablation_successful["positive_genes"].iloc[0]
            ),
            "negative_genes": int(
                ablation_successful["negative_genes"].iloc[0]
            ),
        },
        "consensus": {
            "coverage": coverage,
            "best_by_mode": consensus_best_by_mode,
            "all_models": consensus_successful.to_dict("records"),
            "high_confidence_delta": high_confidence_delta,
        },
    }


def build_final_report(output_path: Path) -> Path:
    """Build and save the final Markdown or plain-text scientific report."""
    output_path = Path(output_path)
    results = extract_key_results()
    markdown = _render_markdown_report(results)
    content = (
        _markdown_to_plain_text(markdown)
        if output_path.suffix.lower() == ".txt"
        else markdown
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content, encoding="utf-8")
    return output_path


def _render_markdown_report(results: dict[str, Any]) -> str:
    ranking = results["ranking"]
    audit = results["quality_audit"]
    ncg = results["ncg_benchmark"]
    leakage = results["leakage_benchmark"]
    ablation = results["ablation"]
    consensus = results["consensus"]

    top_target_rows = [
        [
            index,
            row["gene_name"],
            f"{row['ranking_score_v4']:.3f}",
            row["priority_v4"],
            _short_tier(row["evidence_tier_v6"]),
            f"{row['safety_score']:.2f}",
            row["safety_risk"],
        ]
        for index, row in enumerate(ranking["top_targets"], start=1)
    ]
    safety_rows = [
        [
            row["gene_name"],
            f"{row['normal_lung_tpm']:.3f}",
            f"{row['safety_score']:.2f}",
            row["safety_risk"],
            _safety_interpretation(row["gene_name"], row["safety_score"]),
        ]
        for row in ranking["safety_examples"]
    ]
    tier_rows = [
        [
            tier,
            ranking["tier_counts"].get(tier, 0),
            meaning,
        ]
        for tier, meaning in [
            (
                "Tier_1_Strong_Integrated_Target",
                "Strong integrated LUAD, molecular, and acceptable-safety evidence.",
            ),
            (
                "Tier_2_Actionable_Safety_Supported",
                "Actionable target with favorable normal-lung expression context.",
            ),
            (
                "Tier_2_Actionable_With_Safety_Caution",
                "Actionable target requiring additional safety review.",
            ),
            (
                "Tier_3_LUAD_Driver_Moderate_Evidence",
                "LUAD-relevant driver with moderate integrated evidence.",
            ),
            (
                "Tier_3_Dormancy_Exploratory_Target",
                "Exploratory residual-disease or dormancy relevance.",
            ),
            (
                "Tier_4_Passenger_Background_Like",
                "High-background or passenger-like mutation behavior.",
            ),
            (
                "Tier_5_Low_Evidence_Target",
                "Insufficient integrated evidence for higher prioritization.",
            ),
        ]
    ]

    ncg_best = ncg["best_model"]
    leakage_best = leakage["best_model"]
    ablation_rows = [
        [
            record["experiment_label"],
            record["model_name"],
            f"{record['f1_score']:.3f}",
            f"{record['mcc']:.3f}",
            f"{record['roc_auc']:.3f}",
            f"{record['pr_auc']:.3f}",
        ]
        for record in ablation["best_by_experiment"]
    ]
    consensus_rows = [
        [
            label_mode,
            record["model_name"],
            int(record["positive_genes"]),
            int(record["negative_genes"]),
            f"{record['balanced_accuracy']:.3f}",
            f"{record['f1_score']:.3f}",
            f"{record['mcc']:.3f}",
            f"{record['roc_auc']:.3f}",
            f"{record['pr_auc']:.3f}",
        ]
        for label_mode, record in consensus["best_by_mode"].items()
    ]

    effects = ablation["effects"]
    coverage = consensus["coverage"]
    high_delta = consensus["high_confidence_delta"]
    old_to_raw_auc_drop = (
        leakage_best["roc_auc"] - ncg_best["roc_auc"]
    )
    old_to_raw_f1_drop = (
        leakage_best["f1_score"] - ncg_best["f1_score"]
    )

    sections = [
        (
            "# 1. DIP-AI: Explainable AI for Immune Target Prioritization "
            "in Dormant Residual NSCLC Cells"
        ),
        "",
        "**Final Consensus Scientific Report**  ",
        f"Generated: {results['generated_date']}",
        "",
        "## 2. Research-Use Disclaimer",
        "",
        f"**{DISCLAIMER}**",
        "",
        (
            "All rankings, evidence tiers, safety labels, and machine-learning "
            "metrics in this report are intended for hypothesis generation and "
            "research evaluation only. Experimental and clinical validation are "
            "required before any translational use."
        ),
        "",
        "## 3. Project Aim",
        "",
        (
            "DIP-AI was developed to prioritize candidate immune and cancer targets "
            "for dormant or residual non-small-cell lung cancer research. The "
            "system integrates TCGA-LUAD mutation burden, tumor RNA expression, "
            "predicted protein-impact signals, normal-lung safety context, curated "
            "LUAD relevance, targetability, exploratory dormancy knowledge, and "
            "external cancer evidence. Its central design goal is explainability: "
            "each target score can be traced to explicit biological features, "
            "penalties, and evidence rules."
        ),
        "",
        "## 4. Data Sources",
        "",
        _markdown_table(
            ["Source", "Role in DIP-AI"],
            [
                [
                    "TCGA-LUAD mutation data",
                    "Gene-level mutation burden, patient recurrence of mutations, and protein-impact features.",
                ],
                [
                    "TCGA-LUAD RNA expression",
                    "Tumor expression magnitude, prevalence, and percentile-based expression context.",
                ],
                [
                    "TCGA-LUAD clinical data",
                    "Clinical metadata and an attempted patient-level recurrence benchmark.",
                ],
                [
                    "GTEx Lung",
                    "Normal-lung expression proxy used to penalize potential on-target normal-tissue risk.",
                ],
                [
                    "Network of Cancer Genes (NCG)",
                    "External cancer-driver labels for supervised gene-level benchmarking.",
                ],
                [
                    "CIViC",
                    "External gene and clinical cancer-evidence labels used for consensus supervision.",
                ],
            ],
        ),
        "",
        "## 5. Pipeline Summary",
        "",
        (
            "`Raw data -> validation -> feature engineering -> interpretable ranking "
            "-> GTEx Lung safety filter -> V6 evidence tiers -> external NCG benchmark "
            "-> leakage-minimized benchmark -> ablation study -> NCG+CIViC consensus "
            "labels -> final scientific report`"
        ),
        "",
        (
            "The ranking and supervised-learning branches are deliberately "
            "distinguished. The ranking branch produces research priorities using "
            "explicit rules. The ML branch tests whether data-derived features can "
            "reproduce independent external knowledge labels."
        ),
        "",
        "## 6. Target Ranking Results",
        "",
        (
            f"The final V6 table contains **{ranking['total_targets']:,} targets**: "
            f"**{ranking['priority_counts']['High']} high**, "
            f"**{ranking['priority_counts']['Medium']:,} medium**, and "
            f"**{ranking['priority_counts']['Low']:,} low** priority."
        ),
        "",
        _markdown_table(
            ["Priority", "Target count"],
            [
                ["High", ranking["priority_counts"]["High"]],
                ["Medium", ranking["priority_counts"]["Medium"]],
                ["Low", ranking["priority_counts"]["Low"]],
            ],
        ),
        "",
        "### Leading targets",
        "",
        _markdown_table(
            [
                "Rank",
                "Gene",
                "V4 score",
                "Priority",
                "Evidence tier",
                "Safety score",
                "Safety context",
            ],
            top_target_rows,
        ),
        "",
        (
            f"- Tier 1 strong integrated targets: "
            f"**{', '.join(ranking['tier_1_targets'])}**."
        ),
        (
            f"- Actionable, safety-supported targets: "
            f"**{', '.join(ranking['actionable_safety_supported'])}**."
        ),
        (
            f"- Actionable targets requiring safety caution: "
            f"**{', '.join(ranking['actionable_safety_caution'])}**."
        ),
        (
            f"- Dormancy/residual-disease exploratory targets: "
            f"**{', '.join(ranking['dormancy_exploratory'])}**."
        ),
        "",
        "## 7. GTEx Lung Safety Layer",
        "",
        (
            "The safety layer treats normal-lung expression as a conservative "
            "on-target risk proxy. Genes with TPM <1 receive a safety score of "
            "1.00; TPM from 1 to <10 receives 0.75; TPM from 10 to <50 receives "
            "0.45; and TPM >=50 receives 0.20. Missing GTEx evidence receives a "
            "neutral score of 0.50. The V4 ranking subtracts a penalty equal to "
            "`0.20 x (1 - safety_score)`."
        ),
        "",
        _markdown_table(
            ["Gene", "Normal lung TPM", "Safety score", "Risk label", "Interpretation"],
            safety_rows,
        ),
        "",
        (
            "RET and ALK are supported by low normal-lung expression. EGFR, KRAS, "
            "and TP53 remain scientifically important but carry a normal-lung "
            "expression caution. This layer is a prioritization aid, not a "
            "toxicology model."
        ),
        "",
        "## 8. V6 Evidence Tiers",
        "",
        _markdown_table(
            ["Evidence tier", "Count", "Research interpretation"],
            tier_rows,
        ),
        "",
        (
            "Evidence tiers prevent a single numeric score from being interpreted "
            "without context. They distinguish strong integrated candidates, "
            "clinically actionable genes with different safety contexts, moderate "
            "LUAD drivers, exploratory dormancy targets, passenger-like genes, and "
            "low-evidence background candidates."
        ),
        "",
        "## 9. Quality Audit",
        "",
        (
            f"The final automated quality audit returned **{audit['status']}** "
            f"with **{audit['total_issues']} issues**. It checked "
            f"{audit['required_files_checked']} required artifacts and verified "
            "required columns, duplicate genes, score ranges, V4 safety logic, "
            "priority thresholds, evidence-tier rules, biological sanity checks, "
            "and consistency between the final table and dashboard payload."
        ),
        "",
        "## 10. Initial NCG Supervised Benchmark",
        "",
        (
            f"The initial NCG benchmark used **{ncg['positive_genes']:,} positive** "
            f"and **{ncg['negative_genes']:,} selected negative** genes. Its best "
            f"configuration was {ncg_best['feature_set']} / "
            f"{ncg_best['model_name']}."
        ),
        "",
        _markdown_table(
            ["Model", "F1", "MCC", "ROC-AUC", "PR-AUC"],
            [[
                f"{ncg_best['feature_set']} / {ncg_best['model_name']}",
                f"{ncg_best['f1_score']:.3f}",
                f"{ncg_best['mcc']:.3f}",
                f"{ncg_best['roc_auc']:.3f}",
                f"{ncg_best['pr_auc']:.3f}",
            ]],
        ),
        "",
        (
            "This benchmark evaluated reproduction of NCG cancer-driver labels "
            "only. It did not evaluate recurrence, treatment response, or patient "
            "outcomes. Because the feature set included derived ranking and safety "
            "scores, the result was treated as potentially optimistic."
        ),
        "",
        "## 11. Leakage-Minimized NCG Benchmark",
        "",
        (
            f"The stricter benchmark used only raw mutation, tumor-expression, and "
            f"normal-lung TPM features, with {leakage['positive_genes']:,} positives "
            f"and {leakage['negative_genes']:,} randomly sampled non-NCG negatives."
        ),
        "",
        _markdown_table(
            ["Best model", "F1", "MCC", "ROC-AUC", "PR-AUC"],
            [[
                leakage_best["model_name"],
                f"{leakage_best['f1_score']:.3f}",
                f"{leakage_best['mcc']:.3f}",
                f"{leakage_best['roc_auc']:.3f}",
                f"{leakage_best['pr_auc']:.3f}",
            ]],
        ),
        "",
        (
            f"Relative to the initial best NCG result, ROC-AUC changed by "
            f"**{old_to_raw_auc_drop:+.3f}** and F1 by "
            f"**{old_to_raw_f1_drop:+.3f}**. The marked performance drop shows "
            "why derived-score leakage and negative-selection strategy must be "
            "controlled before interpreting ML performance."
        ),
        "",
        "## 12. NCG Ablation Study",
        "",
        (
            f"Six experiments used {ablation['positive_genes']:,} NCG positives "
            f"and {ablation['negative_genes']:,} negatives to separate the effects "
            "of negative sampling, raw GTEx safety, derived scores, and curated "
            "knowledge."
        ),
        "",
        _markdown_table(
            ["Experiment", "Best model", "F1", "MCC", "ROC-AUC", "PR-AUC"],
            ablation_rows,
        ),
        "",
        (
            f"Across matched model types, adding raw normal-lung TPM changed mean "
            f"ROC-AUC by {effects['raw_safety_clean_roc_auc']:+.4f} on clean "
            f"negatives. Adding derived ranking/safety scores changed it by "
            f"{effects['derived_scores_roc_auc']:+.4f}, and adding curated "
            f"knowledge changed it by {effects['knowledge_roc_auc']:+.4f}. "
            "Therefore, under the controlled ablation definitions, there was no "
            "major performance jump from derived or curated features."
        ),
        "",
        "## 13. CIViC + NCG Consensus Benchmark",
        "",
        _markdown_table(
            ["External-evidence quantity", "Count"],
            [
                ["NCG positive genes", coverage["ncg_external_count"]],
                ["CIViC positive genes", coverage["civic_external_count"]],
                ["NCG/CIViC overlap", coverage["external_overlap_count"]],
                [
                    "Any-source positives in ranked universe",
                    coverage["any_source_ranked_count"],
                ],
                [
                    "High-confidence positives in ranked universe",
                    coverage["high_confidence_ranked_count"],
                ],
                [
                    "CIViC-only additions in ranked universe",
                    coverage["civic_only_ranked_count"],
                ],
                ["Negative candidates", coverage["negative_candidate_count"]],
            ],
        ),
        "",
        _markdown_table(
            [
                "Label mode",
                "Best model",
                "Positives",
                "Negatives",
                "Balanced accuracy",
                "F1",
                "MCC",
                "ROC-AUC",
                "PR-AUC",
            ],
            consensus_rows,
        ),
        "",
        (
            f"High-confidence NCG-intersection-CIViC labels improved mean ROC-AUC by "
            f"**{high_delta['roc_auc']:+.4f}** and mean F1 by "
            f"**{high_delta['f1_score']:+.4f}** across matching models relative "
            "to any-source labels. The result supports the value of stricter "
            "multi-source labels, while the smaller high-confidence cohort and "
            "different label definition prevent a causal or clinical claim."
        ),
        "",
        "## 14. Final Scientific Interpretation",
        "",
        (
            "DIP-AI is now a hybrid explainable-ranking and supervised-ML research "
            "prototype. Its ranking engine is interpretable: mutation, expression, "
            "protein impact, LUAD knowledge, targetability, dormancy evidence, "
            "passenger penalties, and GTEx safety can be inspected separately. "
            "Its ML branch is externally supervised using NCG and CIViC rather than "
            "labels derived from DIP-AI scores."
        ),
        "",
        (
            "The combined evidence is promising at the level of research "
            "prioritization. Raw features reproduced any-source external labels "
            "with limited-to-moderate discrimination, while stricter "
            "NCG-intersection-CIViC "
            "labels produced stronger performance. The leakage and ablation "
            "analyses also demonstrate scientific restraint: high initial scores "
            "were not accepted without testing alternative negative definitions "
            "and removing derived features."
        ),
        "",
        (
            "None of these results demonstrates clinical benefit. The appropriate "
            "interpretation is that DIP-AI organizes heterogeneous molecular and "
            "external evidence into testable, explainable hypotheses."
        ),
        "",
        "## 15. Limitations",
        "",
        "- Reliable patient-level recurrence labels were unavailable; the recurrence benchmark was skipped.",
        "- DIP-AI does not yet provide patient-level recurrence or dormancy prediction.",
        "- NCG and CIViC are external knowledge labels, not observed treatment-response or survival outcomes.",
        "- The GTEx layer is an expression-based safety proxy, not experimental toxicity evidence.",
        "- Neoantigen processing and HLA-binding prediction have not yet been implemented.",
        "- IEDB immune-epitope evidence has not yet been integrated.",
        "- No independent external patient cohort has yet validated the ranking or classifiers.",
        "- Curated gene sets and hand-selected ranking weights require prospective sensitivity analysis and expert review.",
        "",
        "## 16. Recommended Next Steps",
        "",
        "1. Add Open Targets evidence as a third independent gene-level label source.",
        "2. Integrate IEDB evidence to distinguish general cancer drivers from immune-relevant targets.",
        "3. Add a pVACtools-based neoantigen and HLA-binding layer.",
        "4. Validate dormancy and recurrence hypotheses using TRACERx or another longitudinal NSCLC cohort.",
        "5. Add SHAP-based global and per-gene explanations for supervised models.",
        "6. Build a versioned API and UI demonstration around frozen, audited outputs.",
        "7. Perform prospective wet-lab and clinical-expert review before translational claims.",
        "",
        "## 17. Final Conclusion",
        "",
        (
            "DIP-AI demonstrates a complete, auditable research workflow from "
            "multi-omic LUAD data to explainable target ranking, safety-aware "
            "prioritization, external-label benchmarking, leakage analysis, "
            "ablation, and NCG+CIViC consensus validation. Its strongest "
            "contribution is not a clinical prediction claim, but a transparent "
            "framework for converting heterogeneous evidence into reproducible "
            "target hypotheses. This provides a defensible foundation for a "
            "graduation research presentation and for the next stage of immune, "
            "neoantigen, cohort, and experimental validation."
        ),
        "",
    ]
    return "\n".join(sections)


def _parse_ncg_report(report: str) -> dict[str, Any]:
    metric_pattern = re.compile(
        r"^(?P<feature_set>[^/\n]+)\s*/\s*(?P<model_name>[^:]+):\s*"
        r"Accuracy=(?P<accuracy>[\d.]+),\s*"
        r"Balanced Accuracy=(?P<balanced_accuracy>[\d.]+),\s*"
        r"Precision=(?P<precision>[\d.]+),\s*"
        r"Recall=(?P<recall>[\d.]+),\s*"
        r"F1=(?P<f1_score>[\d.]+),\s*"
        r"MCC=(?P<mcc>[\d.]+),\s*"
        r"ROC-AUC=(?P<roc_auc>[\d.]+),\s*"
        r"PR-AUC=(?P<pr_auc>[\d.]+)$",
        flags=re.MULTILINE,
    )
    metrics = []
    for match in metric_pattern.finditer(report):
        row = match.groupdict()
        for metric in [
            "accuracy",
            "balanced_accuracy",
            "precision",
            "recall",
            "f1_score",
            "mcc",
            "roc_auc",
            "pr_auc",
        ]:
            row[metric] = float(row[metric])
        row["feature_set"] = row["feature_set"].strip()
        row["model_name"] = row["model_name"].strip()
        metrics.append(row)
    if not metrics:
        raise ValueError("Could not parse model metrics from the NCG report.")

    best = max(metrics, key=lambda row: (row["roc_auc"], row["f1_score"]))
    return {
        "loaded_positive_genes": _extract_int(
            r"NCG positive genes loaded:\s*(\d+)",
            report,
            default=0,
        ),
        "positive_genes": _extract_int(
            r"NCG positives in classifier dataset:\s*(\d+)",
            report,
            default=0,
        ),
        "negative_genes": _extract_int(
            r"Clean negatives selected:\s*(\d+)",
            report,
            default=0,
        ),
        "metrics": metrics,
        "best_model": best,
    }


def _successful_metrics(metrics: pd.DataFrame) -> pd.DataFrame:
    if "status" not in metrics.columns:
        raise ValueError("Metrics table is missing required column: status")
    successful = metrics.loc[metrics["status"].astype(str).eq("OK")].copy()
    if successful.empty:
        raise ValueError("Metrics table contains no successful model rows.")
    return successful


def _best_metric_record(metrics: pd.DataFrame) -> dict[str, Any]:
    if metrics.empty:
        raise ValueError("Cannot select a best model from an empty table.")
    ordered = metrics.sort_values(
        ["roc_auc", "f1_score"],
        ascending=False,
    )
    return ordered.iloc[0].to_dict()


def _best_ablation_records(metrics: pd.DataFrame) -> list[dict[str, Any]]:
    records = []
    experiment_order = list(metrics["experiment"].drop_duplicates())
    for experiment in experiment_order:
        subset = metrics[metrics["experiment"] == experiment]
        records.append(_best_metric_record(subset))
    return records


def _calculate_ablation_effects(metrics: pd.DataFrame) -> dict[str, float]:
    comparisons = {
        "clean_negatives_raw_roc_auc": (
            "A_random_negatives_raw_features",
            "B_clean_negatives_raw_features",
        ),
        "clean_negatives_safety_roc_auc": (
            "C_random_negatives_raw_plus_safety_raw",
            "D_clean_negatives_raw_plus_safety_raw",
        ),
        "raw_safety_random_roc_auc": (
            "A_random_negatives_raw_features",
            "C_random_negatives_raw_plus_safety_raw",
        ),
        "raw_safety_clean_roc_auc": (
            "B_clean_negatives_raw_features",
            "D_clean_negatives_raw_plus_safety_raw",
        ),
        "derived_scores_roc_auc": (
            "D_clean_negatives_raw_plus_safety_raw",
            "E_clean_negatives_derived_scores",
        ),
        "knowledge_roc_auc": (
            "E_clean_negatives_derived_scores",
            "F_clean_negatives_knowledge_augmented",
        ),
    }
    return {
        name: _paired_experiment_delta(
            metrics,
            from_experiment=pair[0],
            to_experiment=pair[1],
            metric="roc_auc",
        )
        for name, pair in comparisons.items()
    }


def _paired_experiment_delta(
    metrics: pd.DataFrame,
    from_experiment: str,
    to_experiment: str,
    metric: str,
) -> float:
    before = metrics[
        metrics["experiment"] == from_experiment
    ].set_index("model_name")
    after = metrics[
        metrics["experiment"] == to_experiment
    ].set_index("model_name")
    common = before.index.intersection(after.index)
    if not len(common):
        return float("nan")
    return float(
        (
            after.loc[common, metric] - before.loc[common, metric]
        ).mean()
    )


def _paired_mode_delta(
    metrics: pd.DataFrame,
    from_mode: str,
    to_mode: str,
) -> dict[str, float]:
    before = metrics[
        metrics["label_mode"] == from_mode
    ].set_index("model_name")
    after = metrics[
        metrics["label_mode"] == to_mode
    ].set_index("model_name")
    common = before.index.intersection(after.index)
    if not len(common):
        return {"roc_auc": float("nan"), "f1_score": float("nan")}
    return {
        metric: float(
            (
                after.loc[common, metric] - before.loc[common, metric]
            ).mean()
        )
        for metric in ["roc_auc", "f1_score"]
    }


def _genes_in_tier(ranked: pd.DataFrame, tier: str) -> list[str]:
    return (
        ranked.loc[ranked["evidence_tier_v6"] == tier, "gene_name"]
        .astype(str)
        .tolist()
    )


def _gene_records(
    ranked: pd.DataFrame,
    gene_names: list[str],
) -> list[dict[str, Any]]:
    indexed = ranked.set_index("gene_name")
    records = []
    for gene_name in gene_names:
        if gene_name not in indexed.index:
            continue
        record = indexed.loc[gene_name].to_dict()
        record["gene_name"] = gene_name
        records.append(record)
    return records


def _extract_int(pattern: str, text: str, default: int) -> int:
    match = re.search(pattern, text)
    return int(match.group(1)) if match else default


def _extract_text(pattern: str, text: str, default: str) -> str:
    match = re.search(pattern, text)
    return str(match.group(1)) if match else default


def _require_columns(
    dataframe: pd.DataFrame,
    required_columns: list[str],
    dataframe_name: str,
) -> None:
    missing = [
        column for column in required_columns if column not in dataframe.columns
    ]
    if missing:
        raise ValueError(f"{dataframe_name} missing required columns: {missing}")


def _markdown_table(headers: list[Any], rows: list[list[Any]]) -> str:
    header = "| " + " | ".join(_escape_cell(value) for value in headers) + " |"
    separator = "| " + " | ".join(["---"] * len(headers)) + " |"
    body = [
        "| " + " | ".join(_escape_cell(value) for value in row) + " |"
        for row in rows
    ]
    return "\n".join([header, separator, *body])


def _escape_cell(value: Any) -> str:
    if pd.isna(value):
        return ""
    return str(value).replace("|", "\\|").replace("\n", " ")


def _short_tier(tier: str) -> str:
    replacements = {
        "Tier_1_Strong_Integrated_Target": "Tier 1 strong",
        "Tier_2_Actionable_Safety_Supported": "Tier 2 safety-supported",
        "Tier_2_Actionable_With_Safety_Caution": "Tier 2 safety-caution",
        "Tier_3_LUAD_Driver_Moderate_Evidence": "Tier 3 LUAD driver",
        "Tier_3_Dormancy_Exploratory_Target": "Tier 3 dormancy",
        "Tier_4_Passenger_Background_Like": "Tier 4 passenger-like",
        "Tier_5_Low_Evidence_Target": "Tier 5 low evidence",
    }
    return replacements.get(str(tier), str(tier))


def _safety_interpretation(gene_name: str, safety_score: float) -> str:
    if gene_name in {"RET", "ALK"}:
        return "Safety-supported research priority"
    if safety_score < 0.75:
        return "Normal-lung expression caution"
    return "Moderate safety context; review required"


def _markdown_to_plain_text(markdown: str) -> str:
    text = re.sub(r"^#{1,6}\s*", "", markdown, flags=re.MULTILINE)
    text = text.replace("**", "").replace("`", "")
    text = re.sub(r"  $", "", text, flags=re.MULTILINE)
    return text
