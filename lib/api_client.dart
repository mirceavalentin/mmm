import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:task_manager_app/api_config.dart';
import 'package:task_manager_app/storage_service.dart';

/// 1) Interceptor care atașează Authorization + Content-Type
class AuthInterceptor implements InterceptorContract {
  final StorageService _storage = StorageService();

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      // Setează JSON by default (nu afectează MultipartRequest)
      request.headers.putIfAbsent('Content-Type', () => 'application/json');
    } catch (_) {}
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    // Nicio modificare specială aici; RetryPolicy se ocupă de 401
    return response;
  }

  @override
  Future<bool> shouldInterceptRequest() async => true;

  @override
  Future<bool> shouldInterceptResponse() async => true;
}

/// 2) RetryPolicy: la 401 face refresh și cere retry automat
class ExpiredTokenRetryPolicy extends RetryPolicy {
  final StorageService _storage = StorageService();

  // Câte încercări maxime pe aceeași cerere (1 retry după refresh)
  @override
  int get maxRetryAttempts => 1;

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (response.statusCode == 401) {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) return false;

        final refreshResp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );

        if (refreshResp.statusCode == 200) {
          final m = jsonDecode(refreshResp.body) as Map<String, dynamic>;
          final access = m['accessToken'] as String?;
          final refresh = m['refreshToken'] as String?;
          if (access != null && refresh != null) {
            await _storage.saveTokens(access, refresh);
            // La retry, AuthInterceptor va citi noul access token și îl va adăuga pe cererea reluată.
            return true;
          }
        } else {
          // Refresh eșuat: curățăm token-urile
          await _storage.clearTokens();
        }
      } catch (_) {
        await _storage.clearTokens();
      }
    }
    return false;
  }
}

/// 3) Client centralizat
class ApiClient {
  final InterceptedHttp client;

  ApiClient()
    : client = InterceptedHttp.build(
        interceptors: [AuthInterceptor()],
        retryPolicy: ExpiredTokenRetryPolicy(),
      );

  Future<http.Response> get(String path) {
    return client.get(Uri.parse('${ApiConfig.baseUrl}$path'));
  }

  Future<http.Response> post(String path, dynamic body) {
    return client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String path, dynamic body) {
    return client.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      body: jsonEncode(body),
    );
  }
}
