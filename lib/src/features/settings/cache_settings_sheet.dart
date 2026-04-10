import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../../design_system/app_spacing.dart';

class CacheSettingsSheet extends StatefulWidget {
  const CacheSettingsSheet({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<CacheSettingsSheet> createState() => _CacheSettingsSheetState();
}

class _CacheSettingsSheetState extends State<CacheSettingsSheet> {
  final StaleCacheStore _cacheStore = StaleCacheStore();
  static const List<Duration> _ttlOptions = <Duration>[
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  Duration? _selectedTtl;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ttl = await _cacheStore.loadTtl();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTtl = ttl;
    });
  }

  Future<void> _updateTtl(Duration ttl) async {
    await _cacheStore.saveTtl(ttl);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTtl = ttl;
    });
    widget.onChanged?.call();
  }

  Future<void> _clearCache() async {
    setState(() {
      _clearing = true;
    });
    await _cacheStore.clearAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _clearing = false;
    });
    widget.onChanged?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.cacheSettingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.cacheSettingsSubtitle),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _selectedTtl?.inMilliseconds,
              decoration: InputDecoration(labelText: l10n.cacheTtlLabel),
              items: _ttlOptions
                  .map(
                    (ttl) => DropdownMenuItem<int>(
                      value: ttl.inMilliseconds,
                      child: Text(_ttlLabel(l10n, ttl)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateTtl(Duration(milliseconds: value));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _clearing ? null : _clearCache,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  _clearing ? l10n.cacheClearingAction : l10n.cacheClearAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ttlLabel(AppLocalizations l10n, Duration ttl) {
    if (ttl.inSeconds == 15) {
      return l10n.cacheTtl15Seconds;
    }
    if (ttl.inMinutes == 1) {
      return l10n.cacheTtl1Minute;
    }
    if (ttl.inMinutes == 5) {
      return l10n.cacheTtl5Minutes;
    }
    return l10n.cacheTtl15Minutes;
  }
}
