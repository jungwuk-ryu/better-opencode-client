import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'app_spacing.dart';

const Color _kDefaultDialogBarrierColor = Color(0x8A000000);

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = _kDefaultDialogBarrierColor,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
    animationStyle: animationStyle,
    builder: (dialogContext) {
      return _AppCenteredModalBackdrop(
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        useSafeArea: useSafeArea,
        child: builder(dialogContext),
      );
    },
  );
}

Future<T?> showAppGeneralDialog<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  RouteTransitionsBuilder? transitionBuilder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = _kDefaultDialogBarrierColor,
  Duration transitionDuration = const Duration(milliseconds: 200),
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AppFullscreenModalBackdrop(
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        child: pageBuilder(dialogContext, animation, secondaryAnimation),
      );
    },
    transitionBuilder: transitionBuilder,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    requestFocus: requestFocus,
  );
}

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    sheetAnimationStyle: sheetAnimationStyle,
    requestFocus: requestFocus,
  );
}

class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    required this.child,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
    this.constraints,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final EdgeInsets insetPadding;
  final BoxConstraints? constraints;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        insetPadding.left,
        insetPadding.top,
        insetPadding.right,
        insetPadding.bottom + mediaQuery.viewInsets.bottom,
      ),
      child: Semantics(
        container: true,
        role: SemanticsRole.dialog,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: MaterialLocalizations.of(context).dialogLabel,
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: constraints ?? const BoxConstraints(),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AppCenteredModalBackdrop extends StatelessWidget {
  const _AppCenteredModalBackdrop({
    required this.barrierDismissible,
    required this.barrierColor,
    required this.useSafeArea,
    required this.child,
  });

  final bool barrierDismissible;
  final Color barrierColor;
  final bool useSafeArea;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final modalChild = useSafeArea ? SafeArea(child: child) : child;
    final size = MediaQuery.sizeOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _AppModalDismissRegion(
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor,
          ),
          Align(
            alignment: Alignment.center,
            child: UnconstrainedBox(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width,
                  maxHeight: size.height,
                ),
                child: modalChild,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppFullscreenModalBackdrop extends StatelessWidget {
  const _AppFullscreenModalBackdrop({
    required this.barrierDismissible,
    required this.barrierColor,
    required this.child,
  });

  final bool barrierDismissible;
  final Color barrierColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _AppModalDismissRegion(
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor,
          ),
          child,
        ],
      ),
    );
  }
}

class _AppModalDismissRegion extends StatelessWidget {
  const _AppModalDismissRegion({
    required this.barrierDismissible,
    required this.barrierColor,
  });

  final bool barrierDismissible;
  final Color barrierColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: barrierDismissible
            ? () => Navigator.of(context).maybePop()
            : null,
        child: ColoredBox(color: barrierColor),
      ),
    );
  }
}
