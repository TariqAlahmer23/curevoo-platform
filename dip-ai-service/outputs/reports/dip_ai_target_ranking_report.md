# DIP-AI Target Ranking Report

**Disclaimer:** Research use only. This report is not intended for diagnosis, treatment selection, or clinical decision-making.

## Overview

- Total targets: 17705
- High priority: 2
- Medium priority: 722
- Low priority: 16981

## Evidence Tier Summary

| evidence_tier_v6 | target_count |
| --- | --- |
| Tier_5_Low_Evidence_Target | 17671 |
| Tier_4_Passenger_Background_Like | 15 |
| Tier_3_LUAD_Driver_Moderate_Evidence | 8 |
| Tier_2_Actionable_With_Safety_Caution | 5 |
| Tier_1_Strong_Integrated_Target | 2 |
| Tier_2_Actionable_Safety_Supported | 2 |
| Tier_3_Dormancy_Exploratory_Target | 2 |

## Target Category Summary

| target_category_v6 | target_count |
| --- | --- |
| General Candidate | 17653 |
| Passenger-like / Background Mutation | 15 |
| Driver / LUAD Relevant | 14 |
| Dormancy / Residual Exploratory | 12 |
| Clinically Actionable / Safety Caution | 6 |
| Clinically Actionable / Safety Supported | 5 |

## Top 20 Targets

| rank | gene_name | ranking_score_v4 | priority_v4 | evidence_tier_v6 | target_category_v6 | safety_score | safety_risk | normal_lung_tpm | evidence_tier_explanation_v6 | explanation_v4 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | TP53 | 0.7467469989859153 | High | Tier_1_Strong_Integrated_Target | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 12.7462 | Strong integrated evidence from LUAD relevance, mutation/expression/protein-impact, and acceptable safety | Known LUAD/NSCLC relevant gene; Frequently mutated across patients; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 2 | KRAS | 0.7165309747578339 | High | Tier_1_Strong_Integrated_Target | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 16.5553 | Strong integrated evidence from LUAD relevance, mutation/expression/protein-impact, and acceptable safety | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; Frequently mutated across patients; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 3 | EGFR | 0.648261370270435 | Medium | Tier_2_Actionable_With_Safety_Caution | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 20.373 | Clinically actionable LUAD target, but normal lung expression requires safety review | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 4 | RET | 0.6344917667131517 | Medium | Tier_2_Actionable_Safety_Supported | Clinically Actionable / Safety Supported | 1.0 | Low_Normal_Expression | 0.49394 | Clinically actionable LUAD target with low or moderate normal lung expression | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; Low normal lung expression supports safety priority |
| 5 | KEAP1 | 0.596899031339233 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 40.6013 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 6 | ALK | 0.5921365493153262 | Medium | Tier_2_Actionable_Safety_Supported | Clinically Actionable / Safety Supported | 1.0 | Low_Normal_Expression | 0.083896 | Clinically actionable LUAD target with low or moderate normal lung expression | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; Low normal lung expression supports safety priority |
| 7 | BRAF | 0.5900874854171028 | Medium | Tier_2_Actionable_With_Safety_Caution | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 10.2671 | Clinically actionable LUAD target, but normal lung expression requires safety review | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 8 | ROS1 | 0.585490596502775 | Medium | Tier_2_Actionable_With_Safety_Caution | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 13.392 | Clinically actionable LUAD target, but normal lung expression requires safety review | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 9 | MET | 0.5810250611106098 | Medium | Tier_2_Actionable_With_Safety_Caution | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 10.1099 | Clinically actionable LUAD target, but normal lung expression requires safety review | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 10 | ATM | 0.5777184817680159 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.75 | Moderate_Normal_Expression | 9.24853 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; Moderate normal lung expression; safety acceptable but should be reviewed |
| 11 | CDKN2A | 0.5554051138216871 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.75 | Moderate_Normal_Expression | 1.21422 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; Moderate normal lung expression; safety acceptable but should be reviewed |
| 12 | ERBB2 | 0.5549246058276986 | Medium | Tier_2_Actionable_With_Safety_Caution | Clinically Actionable / Safety Caution | 0.45 | High_Normal_Expression | 48.7264 | Clinically actionable LUAD target, but normal lung expression requires safety review | Known LUAD/NSCLC relevant gene; Clinically targetable/actionable gene; High tumor RNA expression; High normal lung expression; safety caution applied |
| 13 | STK11 | 0.5455955407826508 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 30.8137 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 14 | COL11A1 | 0.5381872173533779 | Medium | Tier_5_Low_Evidence_Target | General Candidate | 1.0 | Low_Normal_Expression | 0.119542 | Insufficient integrated evidence | High tumor RNA expression; High protein-impact mutation ratio; Low normal lung expression supports safety priority |
| 15 | SMARCA4 | 0.5369222670734995 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 26.6601 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 16 | SETD2 | 0.529646170741021 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 26.3077 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 17 | MAP2K1 | 0.5205360660040906 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 37.0368 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 18 | ARID1A | 0.5154407243062068 | Medium | Tier_3_LUAD_Driver_Moderate_Evidence | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 32.3673 | LUAD-relevant driver with moderate evidence but not high enough for Tier 1 | Known LUAD/NSCLC relevant gene; High tumor RNA expression; High protein-impact mutation ratio; High normal lung expression; safety caution applied |
| 19 | SOX2 | 0.4947807508277804 | Medium | Tier_3_Dormancy_Exploratory_Target | Dormancy / Residual Exploratory | 1.0 | Low_Normal_Expression | 0.650533 | Exploratory dormancy/residual disease relevance; research-use only | High tumor RNA expression; High protein-impact mutation ratio; Exploratory dormancy/residual disease association; Low normal lung expression supports safety priority |
| 20 | PIK3CA | 0.4915433663261147 | Medium | Tier_5_Low_Evidence_Target | Driver / LUAD Relevant | 0.45 | High_Normal_Expression | 15.2689 | Insufficient integrated evidence | Known LUAD/NSCLC relevant gene; High protein-impact mutation ratio; High normal lung expression; safety caution applied |

## Interpretation

The top-ranked targets combine mutation burden, RNA expression, predicted protein impact, LUAD/NSCLC relevance, clinical targetability, exploratory dormancy evidence, and GTEx Lung safety context. Higher tiers should be treated as stronger research candidates, while safety-caution and passenger-like labels should be reviewed before prioritization.
