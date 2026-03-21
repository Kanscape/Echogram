import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dashboard_models.dart';

class DashboardApiException implements Exception {
  const DashboardApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'DashboardApiException(statusCode: $statusCode, message: $message)';
}

class DashboardApiClient {
  DashboardApiClient({required this.connection, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final DashboardConnection connection;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(connection.apiBaseUrl);
    final baseSegments = base.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );
    final pathSegments = path.split('/').where((segment) => segment.isNotEmpty);
    return base.replace(
      pathSegments: [...baseSegments, ...pathSegments],
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  Future<DashboardMeta> getMeta() async {
    return DashboardMeta.fromJson(await _getMap('meta'));
  }

  Future<DashboardOverview> getOverview() async {
    return DashboardOverview.fromJson(await _getMap('overview'));
  }

  Future<Map<String, String>> getSettings() async {
    final json = await _getMap('settings');
    return json.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Future<Map<String, String>> patchSettings(Map<String, String> changes) async {
    final json = readMap(
      await _request('PATCH', 'settings', jsonBody: changes),
    );
    final updated = readMap(json['updated']);
    return updated.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Future<List<ChatSummary>> getChats({int limit = 20}) async {
    final json = await _getList('chats', queryParameters: {'limit': '$limit'});
    return json.map((item) => ChatSummary.fromJson(readMap(item))).toList();
  }

  Future<ChatDetail> getChat(int chatId) async {
    return ChatDetail.fromJson(await _getMap('chats/$chatId'));
  }

  Future<RecentMessagePage> getRecentMessages(
    int chatId, {
    int limit = 12,
    int offset = 0,
  }) async {
    return RecentMessagePage.fromJson(
      await _getMap(
        'chats/$chatId/messages',
        queryParameters: {'limit': '$limit', 'offset': '$offset'},
      ),
    );
  }

  Future<PromptPreview> getPromptPreview(int chatId) async {
    return PromptPreview.fromJson(
      await _getMap('chats/$chatId/prompt-preview'),
    );
  }

  Future<RagRecordPage> getRagRecords(
    int chatId, {
    int limit = 12,
    int offset = 0,
  }) async {
    return RagRecordPage.fromJson(
      await _getMap(
        'chats/$chatId/rag-records',
        queryParameters: {'limit': '$limit', 'offset': '$offset'},
      ),
    );
  }

  Future<void> rebuildRag(int chatId) async {
    await _request('POST', 'chats/$chatId/rag/rebuild');
  }

  Future<LogSnapshot> getLogs({int charLimit = 8000}) async {
    return LogSnapshot.fromJson(
      await _getMap('logs/recent', queryParameters: {'limit': '$charLimit'}),
    );
  }

  Future<List<SubscriptionRecord>> getSubscriptions() async {
    final json = await _getList('subscriptions');
    return json
        .map((item) => SubscriptionRecord.fromJson(readMap(item)))
        .toList();
  }

  Future<ExtensionCatalog> getExtensions() async {
    return ExtensionCatalog.fromJson(await _getMap('extensions'));
  }

  Future<DashboardExtension> getExtension(String extensionId) async {
    return (await getExtensionDetail(extensionId)).extension;
  }

  Future<ExtensionDetail> getExtensionDetail(String extensionId) async {
    return ExtensionDetail.fromJson(await _getMap('extensions/$extensionId'));
  }

  Future<ExtensionDetail> setExtensionEnabled(
    String extensionId, {
    required bool enabled,
  }) async {
    return ExtensionDetail.fromJson(
      await _request(
        'POST',
        'extensions/$extensionId/${enabled ? 'enable' : 'disable'}',
      ),
    );
  }

  Future<ExtensionDetail> patchExtensionConfig(
    String extensionId, {
    required Map<String, dynamic> values,
    List<String> clearKeys = const [],
  }) async {
    return ExtensionDetail.fromJson(
      await _request(
        'PATCH',
        'extensions/$extensionId/config',
        jsonBody: {'values': values, 'clear_keys': clearKeys},
      ),
    );
  }

  Future<ExtensionInstallResult> installExtension(
    Map<String, dynamic> payload,
  ) async {
    return ExtensionInstallResult.fromJson(
      await _request('POST', 'extensions/install', jsonBody: payload),
    );
  }

  Future<ExtensionInstallResult> installExtensionZip(
    List<int> bytes,
    String filename, {
    bool overwrite = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri('extensions/install'));
    request.headers.addAll(connection.headers());
    request.fields['overwrite'] = overwrite ? 'true' : 'false';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _decodeResponseBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = body is Map<String, dynamic> ? body : const {};
      throw DashboardApiException(
        readString(errorBody['error'], fallback: 'Request failed'),
        statusCode: response.statusCode,
      );
    }

    return ExtensionInstallResult.fromJson(readMap(body));
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final data = await _request('GET', path, queryParameters: queryParameters);
    return readMap(data);
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final data = await _request('GET', path, queryParameters: queryParameters);
    return readList(data);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? jsonBody,
  }) async {
    final uri = _uri(path, queryParameters);
    late http.Response response;
    final headers = {
      ...connection.headers(),
      if (jsonBody != null) 'Content-Type': 'application/json',
    };

    if (method == 'GET') {
      response = await _httpClient.get(uri, headers: headers);
    } else if (method == 'POST') {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonBody == null ? null : jsonEncode(jsonBody),
      );
    } else if (method == 'PATCH') {
      response = await _httpClient.patch(
        uri,
        headers: headers,
        body: jsonEncode(jsonBody ?? const <String, String>{}),
      );
    } else {
      throw DashboardApiException('Unsupported method: $method');
    }

    final body = _decodeResponseBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = body is Map<String, dynamic> ? body : const {};
      throw DashboardApiException(
        readString(errorBody['error'], fallback: 'Request failed'),
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  dynamic _decodeResponseBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      final preview = response.body.trimLeft();
      throw DashboardApiException(
        preview.startsWith('<')
            ? 'Dashboard endpoint returned HTML instead of JSON.'
            : 'Dashboard endpoint returned invalid JSON.',
        statusCode: response.statusCode,
      );
    }
  }
}
