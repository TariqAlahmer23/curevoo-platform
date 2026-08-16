import 'package:curevoo_doctor/repos/main_repo.dart';

class GenomicTargetPrioritizationRepo {
  GenomicTargetPrioritizationRepo({
    required MainRepo mainRepo,
    this.basePath = '/api/ai/genomic-target-prioritization',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String basePath;

  Future<dynamic> checkHealth(String token) {
    return _mainRepo.get(
      _normalizeApiEndpoint('$basePath/health'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> analyze(
    String token, {
    required int topN,
    MultipartFileData? mutationsFile,
    MultipartFileData? expressionFile,
  }) {
    final files = [
      if (mutationsFile != null) mutationsFile,
      if (expressionFile != null) expressionFile,
    ];

    return _mainRepo.postMultipart(
      _normalizeApiEndpoint('$basePath/analyze'),
      headers: {'Authorization': 'Bearer $token'},
      fields: {'topN': topN},
      files: files,
    );
  }

  Future<dynamic> fetchResult(String token, {required String runId}) {
    return _mainRepo.get(
      _normalizeApiEndpoint('$basePath/results/$runId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> fetchReport(String token, {required String runId}) {
    return _mainRepo.get(
      _normalizeApiEndpoint('$basePath/results/$runId/report'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'text/markdown'},
    );
  }

  String _normalizeApiEndpoint(String endpoint) {
    final normalizedBase = _mainRepo.baseUrl.toLowerCase().trim();
    final normalizedEndpoint = endpoint.toLowerCase().trim();

    if (normalizedBase.endsWith('/api') &&
        normalizedEndpoint.startsWith('/api/')) {
      return endpoint.substring(4);
    }

    return endpoint;
  }

  void close() {
    _mainRepo.close();
  }
}
