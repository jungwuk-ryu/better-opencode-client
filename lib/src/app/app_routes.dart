import 'dart:convert';

import '../features/connection/connection_profile_import.dart';

sealed class AppRouteData {
  const AppRouteData();

  factory AppRouteData.parse(String? location) {
    final uri = Uri.tryParse(location ?? '/') ?? Uri(path: '/');
    final routeSegments = <String>[
      if (_usesHostAsTopLevelRoute(uri)) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
    final segments = routeSegments.where((segment) => segment.isNotEmpty);
    final parts = List<String>.from(segments);
    if (parts.isEmpty) {
      return const HomeRouteData();
    }

    final topLevelRoute = parts.first.toLowerCase();
    if (topLevelRoute == 'connect' || topLevelRoute == 'connection') {
      return HomeRouteData(
        connectionImport: ConnectionImportRouteData.fromUri(uri),
      );
    }

    final directory = decodeDirectorySegment(parts.first);
    if (directory == null) {
      return const HomeRouteData();
    }

    if (parts.length == 1) {
      return WorkspaceRouteData(directory: directory);
    }

    if (parts[1] != 'session') {
      return const HomeRouteData();
    }

    final sessionId = parts.length > 2
        ? Uri.decodeComponent(parts.sublist(2).join('/'))
        : null;
    return WorkspaceRouteData(directory: directory, sessionId: sessionId);
  }
}

bool _usesHostAsTopLevelRoute(Uri uri) {
  final scheme = uri.scheme.trim().toLowerCase();
  if (scheme.isEmpty) {
    return false;
  }
  return scheme != 'http' && scheme != 'https' && uri.host.trim().isNotEmpty;
}

class HomeRouteData extends AppRouteData {
  const HomeRouteData({this.connectionImport});

  final ConnectionImportRouteData? connectionImport;
}

class WorkspaceRouteData extends AppRouteData {
  const WorkspaceRouteData({required this.directory, this.sessionId});

  final String directory;
  final String? sessionId;

  String get location => buildWorkspaceRoute(directory, sessionId: sessionId);
}

String encodeDirectorySegment(String directory) {
  return base64Url.encode(utf8.encode(directory)).replaceAll('=', '');
}

String? decodeDirectorySegment(String encoded) {
  if (encoded.isEmpty) {
    return null;
  }

  final normalized = switch (encoded.length % 4) {
    0 => encoded,
    2 => '$encoded==',
    3 => '$encoded=',
    _ => null,
  };
  if (normalized == null) {
    return null;
  }

  try {
    return utf8.decode(base64Url.decode(normalized));
  } catch (_) {
    return null;
  }
}

String buildWorkspaceRoute(String directory, {String? sessionId}) {
  final base = '/${encodeDirectorySegment(directory)}';
  if (sessionId == null) {
    return '$base/session';
  }
  return '$base/session/${Uri.encodeComponent(sessionId)}';
}
