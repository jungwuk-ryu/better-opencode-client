import 'package:flutter/material.dart';

enum ProjectActionKind {
  primary,
  command,
  navigation,
  session,
  git,
  review,
  inbox,
  terminal,
  link,
}

class ProjectActionItem {
  const ProjectActionItem({
    required this.id,
    required this.kind,
    required this.icon,
    required this.title,
    this.subtitle,
    this.description,
    this.commandPreview,
    this.badge,
    this.enabled = true,
    this.attention = false,
    this.destructive = false,
  });

  final String id;
  final ProjectActionKind kind;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? description;
  final String? commandPreview;
  final String? badge;
  final bool enabled;
  final bool attention;
  final bool destructive;
}

class ProjectActionSection {
  const ProjectActionSection({
    required this.id,
    required this.title,
    required this.items,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<ProjectActionItem> items;
}

enum ProjectRuntimeTone { neutral, success, warning, danger, info }

class ProjectServiceSnapshot {
  const ProjectServiceSnapshot({
    required this.id,
    required this.title,
    required this.summary,
    required this.tone,
    this.command,
    this.statusLabel,
  });

  final String id;
  final String title;
  final String summary;
  final ProjectRuntimeTone tone;
  final String? command;
  final String? statusLabel;
}

class RecentRemoteLink {
  const RecentRemoteLink({
    required this.id,
    required this.label,
    required this.url,
    required this.source,
    this.supportingText,
  });

  final String id;
  final String label;
  final String url;
  final String source;
  final String? supportingText;
}

class PortForwardPreset {
  const PortForwardPreset({
    required this.id,
    required this.label,
    required this.localPort,
    required this.remotePort,
    this.host = '127.0.0.1',
    this.description,
  });

  final String id;
  final String label;
  final int localPort;
  final int remotePort;
  final String host;
  final String? description;

  String get command =>
      'ssh -L $localPort:$host:$remotePort <remote-host>';
}
