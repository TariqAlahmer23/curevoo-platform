import 'package:curevoo_doctor/repos/main_repo.dart';

class TreatmentResistanceRepo {
  TreatmentResistanceRepo({
    required MainRepo mainRepo,
    this.nsclcPredictEndpoint = '/api/ai/nsclc/predict',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String nsclcPredictEndpoint;

  Future<dynamic> predictNsclc(
    String token, {
    required Map<String, dynamic> body,
  }) {
    return _mainRepo.post(
      _normalizeApiEndpoint(nsclcPredictEndpoint),
      headers: {'Authorization': 'Bearer $token'},
      body: body,
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
