# Raw Test Output

Verbatim console output from the runs recorded in
[TESTING_REPORT.md](TESTING_REPORT.md). ANSI colour codes and blank lines have
been stripped; no other edits were made.

Backend captures were taken after the DEF-01 fix, so the genomic suite shows 14
tests rather than the 12 present when the defect was first found.

Captured: 17 August 2026

---

## 1. AI Service — pytest (full suite)

```bash
cd dip-ai-service && python -m pytest tests -v
```

```
﻿============================= test session starts =============================
platform win32 -- Python 3.11.9, pytest-9.1.1, pluggy-1.6.0 -- C:\Users\sexyl\AppData\Local\Programs\Python\Python311\python.exe
cachedir: .pytest_cache
rootdir: C:\Users\sexyl\OneDrive\Desktop\Full-Project\dip-ai-service
plugins: anyio-4.12.1
collecting ... collected 40 items
tests/test_ablation_study.py::test_ablation_datasets_share_samples_within_strategy PASSED [  2%]
tests/test_ablation_study.py::test_ablation_feature_families_are_exact PASSED [  5%]
tests/test_ablation_study.py::test_warning_fires_when_derived_scores_dominate PASSED [  7%]
tests/test_civic_consensus.py::test_civic_column_detection_handles_current_exports PASSED [ 10%]
tests/test_civic_consensus.py::test_civic_builder_extracts_genes_and_fusion_partners PASSED [ 12%]
tests/test_civic_consensus.py::test_consensus_label_rules PASSED         [ 15%]
tests/test_civic_consensus.py::test_high_confidence_dataset_excludes_single_source_positives PASSED [ 17%]
tests/test_consensus_final_report.py::test_report_load_helpers PASSED    [ 20%]
tests/test_consensus_final_report.py::test_extract_key_results_matches_final_artifacts PASSED [ 22%]
tests/test_consensus_final_report.py::test_build_final_report_creates_markdown_and_text PASSED [ 25%]
tests/test_leakage_minimized_classifier.py::test_dataset_uses_only_allowed_features_and_samples_negatives PASSED [ 27%]
tests/test_leakage_minimized_classifier.py::test_forbidden_feature_is_rejected PASSED [ 30%]
tests/test_leakage_minimized_classifier.py::test_non_allowed_feature_is_rejected PASSED [ 32%]
tests/test_leakage_minimized_classifier.py::test_training_stops_when_class_counts_are_too_small PASSED [ 35%]
tests/test_prioritization_api.py::test_health_reports_available_artifacts PASSED [ 37%]
tests/test_prioritization_api.py::test_metrics_are_read_from_persisted_evaluation_files PASSED [ 40%]
tests/test_prioritization_api.py::test_skipped_evaluations_are_never_selected_as_primary PASSED [ 42%]
tests/test_prioritization_api.py::test_missing_metrics_files_report_unavailable_instead_of_zero PASSED [ 45%]
tests/test_prioritization_api.py::test_analyze_without_uploads_reports_the_reference_cohort PASSED [ 47%]
tests/test_prioritization_api.py::test_analyze_runs_the_pipeline_over_uploaded_files PASSED [ 50%]
tests/test_prioritization_api.py::test_analyze_rejects_a_single_uploaded_file PASSED [ 52%]
tests/test_prioritization_api.py::test_stored_run_can_be_replayed_and_reported PASSED [ 55%]
tests/test_prioritization_whitebox.py::test_missing_required_mutation_column_is_rejected PASSED [ 57%]
tests/test_prioritization_whitebox.py::test_missing_gene_name_column_in_expression_is_rejected PASSED [ 60%]
tests/test_prioritization_whitebox.py::test_empty_uploaded_file_raises_analysis_input_error PASSED [ 62%]
tests/test_prioritization_whitebox.py::test_mutation_features_count_distinct_patients_not_rows PASSED [ 65%]
tests/test_prioritization_whitebox.py::test_silent_mutations_do_not_inflate_protein_impact PASSED [ 67%]
tests/test_prioritization_whitebox.py::test_expression_features_are_computed_per_gene PASSED [ 70%]
tests/test_prioritization_whitebox.py::test_target_table_joins_mutation_and_expression_on_gene PASSED [ 72%]
tests/test_prioritization_whitebox.py::test_safety_score_decreases_as_normal_lung_expression_rises PASSED [ 75%]
tests/test_prioritization_whitebox.py::test_safety_risk_labels_follow_expression_bands PASSED [ 77%]
tests/test_prioritization_whitebox.py::test_ranking_scores_are_bounded_and_ordered PASSED [ 80%]
tests/test_prioritization_whitebox.py::test_passenger_penalty_is_non_negative PASSED [ 82%]
tests/test_prioritization_whitebox.py::test_known_luad_driver_scores_above_unknown_gene PASSED [ 85%]
tests/test_prioritization_whitebox.py::test_evidence_tiers_and_explanations_are_assigned PASSED [ 87%]
tests/test_prioritization_whitebox.py::test_primary_evaluation_prefers_ok_rows_over_skipped PASSED [ 90%]
tests/test_prioritization_whitebox.py::test_metrics_payload_marks_unavailable_when_no_files_exist PASSED [ 92%]
tests/test_prioritization_whitebox.py::test_metrics_payload_reads_real_benchmark_files PASSED [ 95%]
tests/test_prioritization_whitebox.py::test_markdown_report_contains_disclaimer_and_targets PASSED [ 97%]
tests/test_prioritization_whitebox.py::test_uploaded_files_are_removed_after_analysis PASSED [100%]
============================= 40 passed in 4.30s ==============================
```

---

## 2. Backend — Jest (genomic module only)

```bash
cd Backend && npx jest tests/ai --runInBand --verbose
```

```
PASS tests/ai/genomic-target-prioritization.test.js
  GET /health
    √ reports the AI service as available when the upstream health check succeeds (26 ms)
    √ returns 503 with a safe message when the AI service is unreachable (9 ms)
  POST /analyze
    √ runs the reference cohort when no files are uploaded (18 ms)
    √ exposes the persisted ML metrics in camelCase (6 ms)
    √ always returns the research-use disclaimer (6 ms)
    √ rejects an upload that provides only the mutation file (10 ms)
    √ rejects an upload that provides only the expression file (7 ms)
    √ still runs the reference cohort when neither file is uploaded (4 ms)
    √ rejects an unsupported file type (9 ms)
    √ rejects a topN outside the accepted range (7 ms)
    √ does not leak an upstream Python traceback to the client (5 ms)
  GET /results/:runId
    √ returns a stored run (4 ms)
    √ returns 404 for an unknown run id (5 ms)
  GET /results/:runId/report
    √ returns the generated Markdown report (4 ms)
Test Suites: 1 passed, 1 total
Tests:       14 passed, 14 total
Snapshots:   0 total
Time:        0.922 s, estimated 1 s
Ran all test suites matching /tests\\ai/i.
```

---

## 3. Backend — Jest (full suite)

```bash
cd Backend && npm test
```

```
> curevoo@1.0.0 test
> jest --runInBand
FAIL tests/psychological/psychological.test.js
  ● Black-box: POST /api/psychological/search › يجب أن يرفض النظام الإجابة ويرجع رسالة حماية (Safe Refusal Message) فوراً إذا كان السؤال الطبي خارج نطاق التعليم العام
    expect(received).toBe(expected) // Object.is equality
    Expected: true
    Received: undefined
      59 |
      60 |     expect(response.statusCode).toBe(200);
    > 61 |     expect(response.body.ok).toBe(true);
         |                              ^
      62 |
      63 |     expect(response.body.safety_status).toBe('blocked');
      64 |     expect(response.body.answer).toContain("I cannot give treatment decisions, diagnosis, medication advice");
      at Object.toBe (tests/psychological/psychological.test.js:61:30)
  ● Black-box: POST /api/psychological/search › يجب أن يرجع حالة 200 وقائمة المقالات المنشورة بسلام عند طلب مسار المراجع والتعليم
    expect(received).toBe(expected) // Object.is equality
    Expected: true
    Received: undefined
      74 |
      75 |     expect(response.statusCode).toBe(200);
    > 76 |     expect(response.body.ok).toBe(true);
         |                              ^
      77 |     expect(response.body.data.items).toBeInstanceOf(Array);
      78 |     expect(response.body.data.items[0].title).toBe('What is Immunotherapy?');
      79 |   });
      at Object.toBe (tests/psychological/psychological.test.js:76:30)
FAIL tests/appointments/appointments.test.js
  ● Black-box: POST /api/appointments › يجب أن يحجز الموعد بنجاح وحالة 201 عند إدخال بيانات صحيحة ومكتملة لطبيب متاح
    expect(received).toBe(expected) // Object.is equality
    Expected: 201
    Received: 400
      104 |       });
      105 |
    > 106 |     expect(response.statusCode).toBe(201);
          |                                 ^
      107 |     expect(response.body.ok).toBe(true);
      108 |     expect(response.body.data.status).toBe('PENDING');
      109 |   });
      at Object.toBe (tests/appointments/appointments.test.js:106:33)
PASS tests/ai/genomic-target-prioritization.test.js
PASS tests/patients/patients.test.js
PASS tests/doctor/doctor.test.js
PASS tests/auth/auth.test.js
PASS tests/admin/admin-users.test.js
Test Suites: 2 failed, 5 passed, 7 total
Tests:       3 failed, 27 passed, 30 total
Snapshots:   0 total
Time:        2.112 s, estimated 3 s
Ran all test suites.
```

---

## 4. Frontend — flutter analyze

```bash
cd Frontend && flutter analyze
```

```
﻿Analyzing Frontend...
   info - 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement - lib\widgets\edit_patient_dialog.dart:92:15 - deprecated_member_use
flutter.bat : 1 issue found. (ran in 11.0s)
At line:8 char:1
+ & "C:\Users\sexyl\flutter\bin\flutter.bat" analyze --no-pub 2>&1 | Ou ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (1 issue found. (ran in 11.0s):String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
```

---

## 5. Frontend — flutter test

```bash
cd Frontend && flutter test -r expanded
```

```
﻿00:00 +0: loading C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/genomic_target_prioritization_test.dart
00:00 +0: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/genomic_target_prioritization_test.dart: (setUpAll)
00:00 +0: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/genomic_target_prioritization_test.dart: runs an analysis through the backend and renders ranked targets
00:00 +0 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/genomic_target_prioritization_test.dart: (tearDownAll)
00:00 +0 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: (setUpAll)
00:00 +0 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: unauthenticated users are redirected to login
00:01 +1 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: authenticated users see the dashboard shell
00:01 +2 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: authenticated users visiting login are sent to dashboard
00:02 +3 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: authenticated users visiting signup are sent to dashboard
00:02 +4 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: direct patient route selects patients and renders the page
00:02 +5 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: unknown routes fall back to the authenticated dashboard
00:02 +6 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: login and signup links switch the auth route content
00:03 +7 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: logout redirects protected UI back to login
00:03 +8 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: failed refresh expires the local session
00:03 +9 ~1: C:/Users/sexyl/OneDrive/Desktop/Full-Project/Frontend/test/widget_test.dart: (tearDownAll)
00:03 +9 ~1: All tests passed!
```

---
