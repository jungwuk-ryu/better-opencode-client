import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'project_catalog_service.dart';
import 'project_models.dart';

class ServerDirectoryAutocompleteField extends StatefulWidget {
  const ServerDirectoryAutocompleteField({
    required this.profile,
    required this.catalogService,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.loadingText,
    required this.emptyText,
    this.pathInfo,
    this.focusNode,
    this.fieldKey,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.onSuggestionSelected,
    super.key,
  });

  final ServerProfile profile;
  final ProjectCatalogService catalogService;
  final TextEditingController controller;
  final PathInfo? pathInfo;
  final FocusNode? focusNode;
  final Key? fieldKey;
  final String labelText;
  final String hintText;
  final String loadingText;
  final String emptyText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  State<ServerDirectoryAutocompleteField> createState() =>
      _ServerDirectoryAutocompleteFieldState();
}

class _ServerDirectoryAutocompleteFieldState
    extends State<ServerDirectoryAutocompleteField> {
  static const Duration _debounceDuration = Duration(milliseconds: 180);

  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  Timer? _debounce;
  List<String> _suggestions = const <String>[];
  bool _loading = false;
  bool _searched = false;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    widget.controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant ServerDirectoryAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _scheduleSuggestionRefresh();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_handleFocusChanged);
    }
    if (!widget.enabled && oldWidget.enabled != widget.enabled) {
      _resetSuggestions();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleTextChanged() {
    _scheduleSuggestionRefresh();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _debounce?.cancel();
      setState(() {
        _loading = false;
      });
      return;
    }
    _scheduleSuggestionRefresh();
  }

  void _scheduleSuggestionRefresh() {
    _debounce?.cancel();
    final query = widget.controller.text.trim();
    if (!widget.enabled || !_focusNode.hasFocus || query.isEmpty) {
      _resetSuggestions();
      return;
    }
    _debounce = Timer(_debounceDuration, () {
      unawaited(_refreshSuggestions(query));
    });
  }

  Future<void> _refreshSuggestions(String query) async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final suggestions = await widget.catalogService.suggestDirectories(
        profile: widget.profile,
        input: query,
        pathInfo: widget.pathInfo,
      );
      if (!mounted || token != _requestToken) {
        return;
      }
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _requestToken) {
        return;
      }
      setState(() {
        _suggestions = const <String>[];
        _loading = false;
      });
    }
  }

  void _resetSuggestions() {
    _requestToken += 1;
    if (_suggestions.isEmpty && !_loading && !_searched) {
      return;
    }
    setState(() {
      _suggestions = const <String>[];
      _loading = false;
      _searched = false;
    });
  }

  void _selectSuggestion(String path) {
    widget.controller.value = TextEditingValue(
      text: path,
      selection: TextSelection.collapsed(offset: path.length),
    );
    widget.onSuggestionSelected?.call(path);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final showSuggestions =
        widget.enabled &&
        _focusNode.hasFocus &&
        widget.controller.text.trim().isNotEmpty &&
        (_loading || _suggestions.isNotEmpty || _searched);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.folder_open_rounded),
          ),
          onSubmitted: widget.onSubmitted,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: !showSuggestions
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey<String>('server-directory-suggestions'),
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: surfaces.panel.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    border: Border.all(color: surfaces.line),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: <Widget>[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.loadingText,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: surfaces.muted),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            widget.emptyText,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: surfaces.muted),
                          ),
                        )
                      : Scrollbar(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: surfaces.line.withValues(alpha: 0.72),
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              final basename = projectDisplayLabel(suggestion);
                              return InkWell(
                                key: ValueKey<String>(
                                  'server-directory-suggestion-$index',
                                ),
                                onTap: () => _selectSuggestion(suggestion),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Icon(
                                        Icons.folder_rounded,
                                        size: 18,
                                        color: surfaces.accentSoft,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              basename,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xxs,
                                            ),
                                            Text(
                                              suggestion,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: surfaces.muted,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}
