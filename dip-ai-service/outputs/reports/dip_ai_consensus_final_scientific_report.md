# 1. DIP-AI: Explainable AI for Immune Target Prioritization in Dormant Residual NSCLC Cells

**Final Consensus Scientific Report**  
Generated: 2026-07-25

## 2. Research-Use Disclaimer

**DIP-AI is a research prototype only. It is not a diagnostic system, does not provide treatment recommendations, and must not be used as clinical decision support.**

All rankings, evidence tiers, safety labels, and machine-learning metrics in this report are intended for hypothesis generation and research evaluation only. Experimental and clinical validation are required before any translational use.

## 3. Project Aim

DIP-AI was developed to prioritize candidate immune and cancer targets for dormant or residual non-small-cell lung cancer research. The system integrates TCGA-LUAD mutation burden, tumor RNA expression, predicted protein-impact signals, normal-lung safety context, curated LUAD relevance, targetability, exploratory dormancy knowledge, and external cancer evidence. Its central design goal is explainability: each target score can be traced to explicit biological features, penalties, and evidence rules.

## 4. Data Sources

| Source | Role in DIP-AI |
| --- | --- |
| TCGA-LUAD mutation data | Gene-level mutation burden, patient recurrence of mutations, and protein-impact features. |
| TCGA-LUAD RNA expression | Tumor expression magnitude, prevalence, and percentile-based expression context. |
| TCGA-LUAD clinical data | Clinical metadata and an attempted patient-level recurrence benchmark. |
| GTEx Lung | Normal-lung expression proxy used to penalize potential on-target normal-tissue risk. |
| Network of Cancer Genes (NCG) | External cancer-driver labels for supervised gene-level benchmarking. |
| CIViC | External gene and clinical cancer-evidence labels used for consensus supervision. |

## 5. Pipeline Summary

`Raw data -> validation -> feature engineering -> interpretable ranking -> GTEx Lung safety filter -> V6 evidence tiers -> external NCG benchmark -> leakage-minimized benchmark -> ablation study -> NCG+CIViC consensus labels -> final scientific report`

The ranking and supervised-learning branches are deliberately distinguished. The ranking branch produces research priorities using explicit rules. The ML branch tests whether data-derived features can reproduce independent external knowledge labels.

## 6. Target Ranking Results

The final V6 table contains **17,705 targets**: **2 high**, **722 medium**, and **16,981 low** priority.

| Priority | Target count |
| --- | --- |
| High | 2 |
| Medium | 722 |
| Low | 16981 |

### Leading targets

| Rank | Gene | V4 score | Priority | Evidence tier | Safety score | Safety context |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | TP53 | 0.747 | High | Tier 1 strong | 0.45 | High_Normal_Expression |
| 2 | KRAS | 0.717 | High | Tier 1 strong | 0.45 | High_Normal_Expression |
| 3 | EGFR | 0.648 | Medium | Tier 2 safety-caution | 0.45 | High_Normal_Expression |
| 4 | RET | 0.634 | Medium | Tier 2 safety-supported | 1.00 | Low_Normal_Expression |
| 5 | KEAP1 | 0.597 | Medium | Tier 3 LUAD driver | 0.45 | High_Normal_Expression |
| 6 | ALK | 0.592 | Medium | Tier 2 safety-supported | 1.00 | Low_Normal_Expression |
| 7 | BRAF | 0.590 | Medium | Tier 2 safety-caution | 0.45 | High_Normal_Expression |
| 8 | ROS1 | 0.585 | Medium | Tier 2 safety-caution | 0.45 | High_Normal_Expression |
| 9 | MET | 0.581 | Medium | Tier 2 safety-caution | 0.45 | High_Normal_Expression |
| 10 | ATM | 0.578 | Medium | Tier 3 LUAD driver | 0.75 | Moderate_Normal_Expression |
| 11 | CDKN2A | 0.555 | Medium | Tier 3 LUAD driver | 0.75 | Moderate_Normal_Expression |
| 12 | ERBB2 | 0.555 | Medium | Tier 2 safety-caution | 0.45 | High_Normal_Expression |

- Tier 1 strong integrated targets: **TP53, KRAS**.
- Actionable, safety-supported targets: **RET, ALK**.
- Actionable targets requiring safety caution: **EGFR, BRAF, ROS1, MET, ERBB2**.
- Dormancy/residual-disease exploratory targets: **SOX2, POSTN**.

## 7. GTEx Lung Safety Layer

The safety layer treats normal-lung expression as a conservative on-target risk proxy. Genes with TPM <1 receive a safety score of 1.00; TPM from 1 to <10 receives 0.75; TPM from 10 to <50 receives 0.45; and TPM >=50 receives 0.20. Missing GTEx evidence receives a neutral score of 0.50. The V4 ranking subtracts a penalty equal to `0.20 x (1 - safety_score)`.

| Gene | Normal lung TPM | Safety score | Risk label | Interpretation |
| --- | --- | --- | --- | --- |
| RET | 0.494 | 1.00 | Low_Normal_Expression | Safety-supported research priority |
| ALK | 0.084 | 1.00 | Low_Normal_Expression | Safety-supported research priority |
| EGFR | 20.373 | 0.45 | High_Normal_Expression | Normal-lung expression caution |
| KRAS | 16.555 | 0.45 | High_Normal_Expression | Normal-lung expression caution |
| TP53 | 12.746 | 0.45 | High_Normal_Expression | Normal-lung expression caution |

RET and ALK are supported by low normal-lung expression. EGFR, KRAS, and TP53 remain scientifically important but carry a normal-lung expression caution. This layer is a prioritization aid, not a toxicology model.

## 8. V6 Evidence Tiers

| Evidence tier | Count | Research interpretation |
| --- | --- | --- |
| Tier_1_Strong_Integrated_Target | 2 | Strong integrated LUAD, molecular, and acceptable-safety evidence. |
| Tier_2_Actionable_Safety_Supported | 2 | Actionable target with favorable normal-lung expression context. |
| Tier_2_Actionable_With_Safety_Caution | 5 | Actionable target requiring additional safety review. |
| Tier_3_LUAD_Driver_Moderate_Evidence | 8 | LUAD-relevant driver with moderate integrated evidence. |
| Tier_3_Dormancy_Exploratory_Target | 2 | Exploratory residual-disease or dormancy relevance. |
| Tier_4_Passenger_Background_Like | 15 | High-background or passenger-like mutation behavior. |
| Tier_5_Low_Evidence_Target | 17671 | Insufficient integrated evidence for higher prioritization. |

Evidence tiers prevent a single numeric score from being interpreted without context. They distinguish strong integrated candidates, clinically actionable genes with different safety contexts, moderate LUAD drivers, exploratory dormancy targets, passenger-like genes, and low-evidence background candidates.

## 9. Quality Audit

The final automated quality audit returned **PASS** with **0 issues**. It checked 6 required artifacts and verified required columns, duplicate genes, score ranges, V4 safety logic, priority thresholds, evidence-tier rules, biological sanity checks, and consistency between the final table and dashboard payload.

## 10. Initial NCG Supervised Benchmark

The initial NCG benchmark used **3,178 positive** and **6,356 selected negative** genes. Its best configuration was knowledge_augmented / RandomForestClassifier.

| Model | F1 | MCC | ROC-AUC | PR-AUC |
| --- | --- | --- | --- | --- |
| knowledge_augmented / RandomForestClassifier | 0.747 | 0.672 | 0.852 | 0.838 |

This benchmark evaluated reproduction of NCG cancer-driver labels only. It did not evaluate recurrence, treatment response, or patient outcomes. Because the feature set included derived ranking and safety scores, the result was treated as potentially optimistic.

## 11. Leakage-Minimized NCG Benchmark

The stricter benchmark used only raw mutation, tumor-expression, and normal-lung TPM features, with 3,199 positives and 6,398 randomly sampled non-NCG negatives.

| Best model | F1 | MCC | ROC-AUC | PR-AUC |
| --- | --- | --- | --- | --- |
| LogisticRegressionElasticNet | 0.512 | 0.259 | 0.686 | 0.554 |

Relative to the initial best NCG result, ROC-AUC changed by **-0.166** and F1 by **-0.235**. The marked performance drop shows why derived-score leakage and negative-selection strategy must be controlled before interpreting ML performance.

## 12. NCG Ablation Study

Six experiments used 3,199 NCG positives and 6,398 negatives to separate the effects of negative sampling, raw GTEx safety, derived scores, and curated knowledge.

| Experiment | Best model | F1 | MCC | ROC-AUC | PR-AUC |
| --- | --- | --- | --- | --- | --- |
| A) random_negatives + raw_features | LogisticRegressionElasticNet | 0.509 | 0.255 | 0.686 | 0.554 |
| B) clean_negatives + raw_features | LogisticRegressionElasticNet | 0.507 | 0.255 | 0.684 | 0.555 |
| C) random_negatives + raw_plus_safety_raw | LogisticRegressionElasticNet | 0.512 | 0.259 | 0.686 | 0.554 |
| D) clean_negatives + raw_plus_safety_raw | LogisticRegressionElasticNet | 0.508 | 0.257 | 0.685 | 0.555 |
| E) clean_negatives + derived_scores | LogisticRegressionElasticNet | 0.518 | 0.261 | 0.690 | 0.564 |
| F) clean_negatives + knowledge_augmented | LogisticRegressionElasticNet | 0.517 | 0.260 | 0.690 | 0.566 |

Across matched model types, adding raw normal-lung TPM changed mean ROC-AUC by +0.0072 on clean negatives. Adding derived ranking/safety scores changed it by +0.0014, and adding curated knowledge changed it by +0.0003. Therefore, under the controlled ablation definitions, there was no major performance jump from derived or curated features.

## 13. CIViC + NCG Consensus Benchmark

| External-evidence quantity | Count |
| --- | --- |
| NCG positive genes | 3347 |
| CIViC positive genes | 861 |
| NCG/CIViC overlap | 517 |
| Any-source positives in ranked universe | 3505 |
| High-confidence positives in ranked universe | 504 |
| CIViC-only additions in ranked universe | 306 |
| Negative candidates | 14200 |

| Label mode | Best model | Positives | Negatives | Balanced accuracy | F1 | MCC | ROC-AUC | PR-AUC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| any_source | LogisticRegressionElasticNet | 3505 | 7010 | 0.637 | 0.519 | 0.271 | 0.687 | 0.546 |
| high_confidence | LogisticRegressionElasticNet | 504 | 1008 | 0.690 | 0.596 | 0.363 | 0.760 | 0.623 |

High-confidence NCG-intersection-CIViC labels improved mean ROC-AUC by **+0.0748** and mean F1 by **+0.1080** across matching models relative to any-source labels. The result supports the value of stricter multi-source labels, while the smaller high-confidence cohort and different label definition prevent a causal or clinical claim.

## 14. Final Scientific Interpretation

DIP-AI is now a hybrid explainable-ranking and supervised-ML research prototype. Its ranking engine is interpretable: mutation, expression, protein impact, LUAD knowledge, targetability, dormancy evidence, passenger penalties, and GTEx safety can be inspected separately. Its ML branch is externally supervised using NCG and CIViC rather than labels derived from DIP-AI scores.

The combined evidence is promising at the level of research prioritization. Raw features reproduced any-source external labels with limited-to-moderate discrimination, while stricter NCG-intersection-CIViC labels produced stronger performance. The leakage and ablation analyses also demonstrate scientific restraint: high initial scores were not accepted without testing alternative negative definitions and removing derived features.

None of these results demonstrates clinical benefit. The appropriate interpretation is that DIP-AI organizes heterogeneous molecular and external evidence into testable, explainable hypotheses.

## 15. Limitations

- Reliable patient-level recurrence labels were unavailable; the recurrence benchmark was skipped.
- DIP-AI does not yet provide patient-level recurrence or dormancy prediction.
- NCG and CIViC are external knowledge labels, not observed treatment-response or survival outcomes.
- The GTEx layer is an expression-based safety proxy, not experimental toxicity evidence.
- Neoantigen processing and HLA-binding prediction have not yet been implemented.
- IEDB immune-epitope evidence has not yet been integrated.
- No independent external patient cohort has yet validated the ranking or classifiers.
- Curated gene sets and hand-selected ranking weights require prospective sensitivity analysis and expert review.

## 16. Recommended Next Steps

1. Add Open Targets evidence as a third independent gene-level label source.
2. Integrate IEDB evidence to distinguish general cancer drivers from immune-relevant targets.
3. Add a pVACtools-based neoantigen and HLA-binding layer.
4. Validate dormancy and recurrence hypotheses using TRACERx or another longitudinal NSCLC cohort.
5. Add SHAP-based global and per-gene explanations for supervised models.
6. Build a versioned API and UI demonstration around frozen, audited outputs.
7. Perform prospective wet-lab and clinical-expert review before translational claims.

## 17. Final Conclusion

DIP-AI demonstrates a complete, auditable research workflow from multi-omic LUAD data to explainable target ranking, safety-aware prioritization, external-label benchmarking, leakage analysis, ablation, and NCG+CIViC consensus validation. Its strongest contribution is not a clinical prediction claim, but a transparent framework for converting heterogeneous evidence into reproducible target hypotheses. This provides a defensible foundation for a graduation research presentation and for the next stage of immune, neoantigen, cohort, and experimental validation.
