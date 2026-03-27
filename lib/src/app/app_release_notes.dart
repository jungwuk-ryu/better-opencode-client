import 'package:flutter/material.dart';

class AppReleaseHighlight {
  const AppReleaseHighlight({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class AppReleaseNotes {
  const AppReleaseNotes({
    required this.version,
    required this.headline,
    required this.summary,
    required this.highlights,
  });

  final String version;
  final String headline;
  final String summary;
  final List<AppReleaseHighlight> highlights;
}

class AppReleaseNotesPresentation {
  const AppReleaseNotesPresentation({
    required this.currentVersion,
    required this.headline,
    required this.summary,
    required this.highlights,
    this.previousVersion,
  });

  final String currentVersion;
  final String? previousVersion;
  final String headline;
  final String summary;
  final List<AppReleaseHighlight> highlights;

  String get versionLabel => 'v$currentVersion';
}

const List<AppReleaseNotes> appReleaseNotesCatalog = <AppReleaseNotes>[
  AppReleaseNotes(
    version: '1.0.0',
    headline: 'Workspace parity got a major upgrade.',
    summary:
        'The mobile remote client now covers much more of the upstream workspace flow, from command dispatch to review tooling and notifications.',
    highlights: <AppReleaseHighlight>[
      AppReleaseHighlight(
        title: 'Customize the whole workspace look',
        description:
            'Switch between bundled theme presets and system, light, or dark color modes without restarting the app.',
        icon: Icons.palette_rounded,
      ),
      AppReleaseHighlight(
        title: 'Open a command palette anywhere',
        description:
            'Jump to sessions, change models, run workspace actions, and trigger slash-style commands from one searchable launcher.',
        icon: Icons.keyboard_command_key_rounded,
      ),
      AppReleaseHighlight(
        title: 'Manage MCPs and permissions in-session',
        description:
            'Toggle MCP integrations per session and control default Allow, Ask, or Deny tool policies directly from workspace settings.',
        icon: Icons.extension_rounded,
      ),
      AppReleaseHighlight(
        title: 'Catch pending requests faster',
        description:
            'Permission and question requests now trigger OS notifications, permission sounds, and sidebar unseen badges for projects and sessions.',
        icon: Icons.notifications_active_rounded,
      ),
      AppReleaseHighlight(
        title: 'Review and history tools are deeper',
        description:
            'Long sessions can backfill older history, review panels handle empty states better, and diff hover or comment actions feed context back into the prompt flow.',
        icon: Icons.rate_review_rounded,
      ),
    ],
  ),
];

String? normalizeReleaseNotesVersion(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  if (text.startsWith('v') || text.startsWith('V')) {
    final normalized = text.substring(1).trim();
    return normalized.isEmpty ? null : normalized;
  }
  return text;
}

AppReleaseNotes? get currentAppReleaseNotes =>
    appReleaseNotesCatalog.isEmpty ? null : appReleaseNotesCatalog.first;

AppReleaseNotesPresentation? latestAppReleaseNotesPresentation() {
  final current = currentAppReleaseNotes;
  if (current == null) {
    return null;
  }
  return AppReleaseNotesPresentation(
    currentVersion: normalizeReleaseNotesVersion(current.version) ?? current.version,
    headline: current.headline,
    summary: current.summary,
    highlights: List<AppReleaseHighlight>.unmodifiable(current.highlights),
  );
}

AppReleaseNotesPresentation? releaseNotesSinceVersion(String? previousVersion) {
  final current = currentAppReleaseNotes;
  if (current == null) {
    return null;
  }
  final normalizedPrevious = normalizeReleaseNotesVersion(previousVersion);
  final normalizedCurrent =
      normalizeReleaseNotesVersion(current.version) ?? current.version;
  if (normalizedPrevious == normalizedCurrent) {
    return null;
  }

  final endIndex = normalizedPrevious == null
      ? appReleaseNotesCatalog.length
      : appReleaseNotesCatalog.indexWhere(
          (release) =>
              normalizeReleaseNotesVersion(release.version) ==
              normalizedPrevious,
        );
  final relevantReleases = endIndex == -1
      ? appReleaseNotesCatalog
      : appReleaseNotesCatalog.take(endIndex).toList(growable: false);
  if (relevantReleases.isEmpty) {
    return latestAppReleaseNotesPresentation();
  }

  final seen = <String>{};
  final highlights = <AppReleaseHighlight>[];
  for (final release in relevantReleases) {
    for (final highlight in release.highlights) {
      final key = '${highlight.title}\n${highlight.description}';
      if (!seen.add(key)) {
        continue;
      }
      highlights.add(highlight);
      if (highlights.length >= 5) {
        break;
      }
    }
    if (highlights.length >= 5) {
      break;
    }
  }
  if (highlights.isEmpty) {
    return null;
  }

  return AppReleaseNotesPresentation(
    currentVersion: normalizedCurrent,
    previousVersion: normalizedPrevious,
    headline: current.headline,
    summary: current.summary,
    highlights: List<AppReleaseHighlight>.unmodifiable(highlights),
  );
}
