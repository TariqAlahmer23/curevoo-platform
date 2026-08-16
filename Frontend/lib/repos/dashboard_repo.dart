import 'package:curevoo_doctor/repos/main_repo.dart';

class DashboardRepo {
  DashboardRepo({
    required MainRepo mainRepo,
    this.summaryEndpoint = '/api/doctor/dashboard/summary',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String summaryEndpoint;

  Future<Map<String, dynamic>> fetchSummary(String token) async {
    final response = await _mainRepo.get(
      _resolveSummaryEndpoint(),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _toMap(response);
  }

  String _resolveSummaryEndpoint() {
    return _normalizeApiEndpoint(summaryEndpoint);
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

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic inner) => MapEntry(key.toString(), inner));
    }
    throw ApiException(message: 'Unexpected dashboard summary response type.');
  }

  void close() {
    _mainRepo.close();
  }
}
