import 'dart:convert';

enum ConnectionProbeClassification {
  ready,
  authFailure,
  specFetchFailure,
  unsupportedCapabilities,
  connectivityFailure,
}

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.username,
    this.password,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String? username;
  final String? password;

  String get normalizedBaseUrl => _normalizeBaseUrl(baseUrl);

  String get effectiveLabel {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }
    final uri = uriOrNull;
    if (uri == null) {
      return normalizedBaseUrl;
    }
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.host;
    }
    return '${uri.host}${uri.path}';
  }

  Uri? get uriOrNull {
    final normalized = normalizedBaseUrl;
    if (normalized.isEmpty) {
      return null;
    }
    return Uri.tryParse(normalized);
  }

  bool get hasBasicAuth =>
      (username?.trim().isNotEmpty ?? false) ||
      (password?.trim().isNotEmpty ?? false);

  String get storageKey => '$normalizedBaseUrl|${username?.trim() ?? ''}';

  String? get basicAuthHeader {
    if (!hasBasicAuth) {
      return null;
    }
    final user = username?.trim() ?? '';
    final secret = password ?? '';
    final encoded = base64Encode(utf8.encode('$user:$secret'));
    return 'Basic $encoded';
  }

  ServerProfile copyWith({
    String? id,
    String? label,
    String? baseUrl,
    String? username,
    String? password,
    bool clearUsername = false,
    bool clearPassword = false,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      username: clearUsername ? null : (username ?? this.username),
      password: clearPassword ? null : (password ?? this.password),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'baseUrl': normalizedBaseUrl,
    'username': username,
    'password': password,
  };

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: json['id']! as String,
      label: (json['label'] as String?) ?? '',
      baseUrl: json['baseUrl']! as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) {
      return trimmed;
    }
    final normalizedPath = uri.path == '/'
        ? ''
        : uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri
        .replace(
          path: normalizedPath,
          queryParameters: uri.queryParameters.isEmpty
              ? null
              : uri.queryParameters,
          fragment: null,
        )
        .toString();
  }
}

class RecentConnection {
  const RecentConnection({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.username,
    required this.attemptedAt,
    required this.classification,
    required this.summary,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String? username;
  final DateTime attemptedAt;
  final ConnectionProbeClassification classification;
  final String summary;

  String get storageKey {
    final profile = ServerProfile(
      id: id,
      label: label,
      baseUrl: baseUrl,
      username: username,
    );
    return profile.storageKey;
  }

  ServerProfile toProfile() {
    return ServerProfile(
      id: id,
      label: label,
      baseUrl: baseUrl,
      username: username,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'baseUrl': baseUrl,
    'username': username,
    'attemptedAt': attemptedAt.toIso8601String(),
    'classification': classification.name,
    'summary': summary,
  };

  factory RecentConnection.fromJson(Map<String, Object?> json) {
    return RecentConnection(
      id: json['id']! as String,
      label: (json['label'] as String?) ?? '',
      baseUrl: json['baseUrl']! as String,
      username: json['username'] as String?,
      attemptedAt: DateTime.parse(json['attemptedAt']! as String),
      classification: ConnectionProbeClassification.values.byName(
        json['classification']! as String,
      ),
      summary: json['summary']! as String,
    );
  }
}
