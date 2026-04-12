import 'dart:convert';

import '../../core/connection/connection_models.dart';

enum ConnectionProfileImportAuthType {
  none,
  basic;

  static ConnectionProfileImportAuthType? fromJson(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'none' => ConnectionProfileImportAuthType.none,
      'basic' => ConnectionProfileImportAuthType.basic,
      _ => null,
    };
  }

  String get storageValue => name;
}

final class ConnectionProfileImportPayload {
  const ConnectionProfileImportPayload({
    required this.version,
    required this.label,
    required this.baseUrl,
    required this.authType,
    this.authTypeRaw,
    this.username,
    this.password,
    this.issuedAt,
    this.expiresAt,
  });

  static const int latestVersion = 1;

  final int version;
  final String label;
  final String baseUrl;
  final ConnectionProfileImportAuthType authType;
  final String? authTypeRaw;
  final String? username;
  final String? password;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  bool get hasCredentials =>
      (username?.trim().isNotEmpty ?? false) || (password?.isNotEmpty ?? false);

  bool get isExpired {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    return expiresAt.isBefore(DateTime.now());
  }

  factory ConnectionProfileImportPayload.fromJson(Map<String, Object?> json) {
    final rawAuthType = _normalizedOptional(json['authType']?.toString());
    return ConnectionProfileImportPayload(
      version: (json['version'] as num?)?.toInt() ?? 0,
      label: _normalizedOptional(json['label']?.toString()) ?? '',
      baseUrl: _normalizedOptional(json['baseUrl']?.toString()) ?? '',
      authType:
          ConnectionProfileImportAuthType.fromJson(rawAuthType) ??
          ConnectionProfileImportAuthType.none,
      authTypeRaw: rawAuthType,
      username: _normalizedOptional(json['username']?.toString()),
      password: _normalizedOptional(json['password']?.toString()),
      issuedAt: _dateTimeFromEpochMillis(json['issuedAtMs']),
      expiresAt: _dateTimeFromEpochMillis(json['expiresAtMs']),
    );
  }

  factory ConnectionProfileImportPayload.fromProfile(
    ServerProfile profile, {
    DateTime? issuedAt,
    Duration? expiresIn,
  }) {
    final normalized = profile.canonicalize();
    return ConnectionProfileImportPayload(
      version: latestVersion,
      label: normalized.label.trim(),
      baseUrl: normalized.normalizedBaseUrl,
      authType: normalized.hasBasicAuth
          ? ConnectionProfileImportAuthType.basic
          : ConnectionProfileImportAuthType.none,
      authTypeRaw: normalized.hasBasicAuth ? 'basic' : 'none',
      username: _normalizedOptional(normalized.username),
      password: _normalizedOptional(normalized.password),
      issuedAt: issuedAt,
      expiresAt: expiresIn == null ? null : issuedAt?.add(expiresIn),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'label': label,
    'baseUrl': baseUrl,
    'authType': authTypeRaw ?? authType.storageValue,
    'username': username,
    'password': password,
    'issuedAtMs': issuedAt?.millisecondsSinceEpoch,
    'expiresAtMs': expiresAt?.millisecondsSinceEpoch,
  };

  ServerProfile toServerProfile({String? id}) {
    return ServerProfile(
      id: id ?? 'imported-${base64Url.encode(utf8.encode(baseUrl))}',
      label: label,
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  String toToken() {
    return encodeConnectionProfileImportPayload(this);
  }
}

final class ConnectionProfileImportValidationIssue {
  const ConnectionProfileImportValidationIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  bool operator ==(Object other) {
    return other is ConnectionProfileImportValidationIssue &&
        other.code == code &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(code, message);
}

final class ConnectionProfileImportValidationResult {
  const ConnectionProfileImportValidationResult({
    required this.payload,
    required this.issues,
  });

  final ConnectionProfileImportPayload payload;
  final List<ConnectionProfileImportValidationIssue> issues;

  bool get isValid => issues.isEmpty;

  bool get hasWarnings => issues.isNotEmpty && !isValid;
}

class ConnectionProfileImportValidator {
  const ConnectionProfileImportValidator();

  ConnectionProfileImportValidationResult validateToken(
    String token, {
    DateTime? now,
  }) {
    final payload = decodeConnectionProfileImportPayload(token);
    if (payload == null) {
      return ConnectionProfileImportValidationResult(
        payload: const ConnectionProfileImportPayload(
          version: 0,
          label: '',
          baseUrl: '',
          authType: ConnectionProfileImportAuthType.none,
        ),
        issues: <ConnectionProfileImportValidationIssue>[
          const ConnectionProfileImportValidationIssue(
            code: 'invalid_payload',
            message: 'The import payload could not be decoded.',
          ),
        ],
      );
    }
    return validate(payload, now: now);
  }

  ConnectionProfileImportValidationResult validate(
    ConnectionProfileImportPayload payload, {
    DateTime? now,
  }) {
    final issues = <ConnectionProfileImportValidationIssue>[];
    final currentTime = now ?? DateTime.now();
    if (payload.version != ConnectionProfileImportPayload.latestVersion) {
      issues.add(
        ConnectionProfileImportValidationIssue(
          code: 'unsupported_version',
          message: 'Unsupported import payload version ${payload.version}.',
        ),
      );
    }

    final rawAuthType = payload.authTypeRaw;
    if (rawAuthType == null) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'missing_auth_type',
          message: 'The import payload must specify an authType value.',
        ),
      );
    } else if (rawAuthType != payload.authType.storageValue) {
      issues.add(
        ConnectionProfileImportValidationIssue(
          code: 'unsupported_auth_type',
          message: 'Unsupported authType value "$rawAuthType".',
        ),
      );
    }

    final profile = ServerProfile(
      id: 'import-check',
      label: payload.label,
      baseUrl: payload.baseUrl,
      username: payload.username,
      password: payload.password,
    );
    if (profile.uriOrNull == null) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'invalid_base_url',
          message: 'The import payload does not contain a valid server URL.',
        ),
      );
    }

    if (payload.authType == ConnectionProfileImportAuthType.none &&
        payload.hasCredentials) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'unexpected_credentials',
          message:
              'The payload declares no-auth but includes credential fields.',
        ),
      );
    }

    if (payload.authType == ConnectionProfileImportAuthType.basic &&
        !payload.hasCredentials) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'missing_credentials',
          message: 'Basic-auth payloads must include a username or password.',
        ),
      );
    }

    final expiresAt = payload.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(currentTime)) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'expired_payload',
          message: 'The import payload has expired.',
        ),
      );
    }

    final issuedAt = payload.issuedAt;
    if (issuedAt != null && expiresAt != null && expiresAt.isBefore(issuedAt)) {
      issues.add(
        const ConnectionProfileImportValidationIssue(
          code: 'invalid_expiration',
          message: 'The expiration time must be after the issued time.',
        ),
      );
    }

    return ConnectionProfileImportValidationResult(
      payload: payload,
      issues: List<ConnectionProfileImportValidationIssue>.unmodifiable(issues),
    );
  }
}

final class ConnectionImportRouteData {
  const ConnectionImportRouteData({
    required this.rawPayload,
    required this.validation,
  });

  final String rawPayload;
  final ConnectionProfileImportValidationResult validation;

  ConnectionProfileImportPayload get payload => validation.payload;

  bool get hasValidPayload => validation.isValid;

  String? get location => buildConnectionImportRoute(rawPayload: rawPayload);

  factory ConnectionImportRouteData.fromUri(
    Uri uri, {
    ConnectionProfileImportValidator validator =
        const ConnectionProfileImportValidator(),
  }) {
    final rawPayload = _extractRawImportPayload(uri);
    return ConnectionImportRouteData(
      rawPayload: rawPayload,
      validation: validator.validateToken(rawPayload, now: DateTime.now()),
    );
  }
}

String buildConnectionImportRoute({required String rawPayload}) {
  final trimmed = rawPayload.trim();
  if (trimmed.isEmpty) {
    return '/connect';
  }
  return '/connect?payload=${Uri.encodeComponent(trimmed)}';
}

Uri buildConnectionImportDeepLink({
  required String rawPayload,
  String scheme = 'opencode-remote',
}) {
  return Uri(
    scheme: scheme,
    host: 'connect',
    queryParameters: rawPayload.trim().isEmpty
        ? null
        : <String, String>{'payload': rawPayload.trim()},
  );
}

String encodeConnectionProfileImportPayload(
  ConnectionProfileImportPayload payload,
) {
  final json = jsonEncode(payload.toJson());
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

ConnectionProfileImportPayload? decodeConnectionProfileImportPayload(
  String token,
) {
  final normalizedToken = token.trim();
  if (normalizedToken.isEmpty) {
    return null;
  }

  final decodedJson = _decodeImportToken(normalizedToken);
  if (decodedJson == null) {
    return null;
  }

  if (decodedJson is! Map) {
    return null;
  }

  return ConnectionProfileImportPayload.fromJson(
    decodedJson.cast<String, Object?>(),
  );
}

Object? _decodeImportToken(String token) {
  final asJson = _decodeJsonObject(token);
  if (asJson != null) {
    return asJson;
  }

  final normalized = switch (token.length % 4) {
    0 => token,
    2 => '$token==',
    3 => '$token=',
    _ => null,
  };
  if (normalized == null) {
    return null;
  }

  try {
    final decoded = utf8.decode(base64Url.decode(normalized));
    return _decodeJsonObject(decoded);
  } catch (_) {
    return null;
  }
}

Map<String, Object?>? _decodeJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return decoded.cast<String, Object?>();
  } catch (_) {
    return null;
  }
}

String _extractRawImportPayload(Uri uri) {
  final candidate =
      <String?>[
        uri.queryParameters['payload'],
        uri.queryParameters['profile'],
        uri.queryParameters['data'],
        uri.queryParameters['connection'],
      ].firstWhere(
        (value) => value != null && value.trim().isNotEmpty,
        orElse: () => null,
      );

  if (candidate != null) {
    return candidate;
  }

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return '';
  }

  if (segments.first != 'connect' && segments.first != 'connection') {
    return '';
  }
  if (segments.length == 1) {
    return '';
  }

  return Uri.decodeComponent(segments.sublist(1).join('/'));
}

DateTime? _dateTimeFromEpochMillis(Object? value) {
  final millis = (value as num?)?.toInt();
  if (millis == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

String? _normalizedOptional(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
