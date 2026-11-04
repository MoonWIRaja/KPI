import 'package:flutter/material.dart';
import 'merit_brand.dart';

/// Displays a responsive modal that presents as an iOS/Material-style bottom sheet on mobile screens (< 650px)
/// with a soft drag handle pill, top rounded corners, and virtual keyboard avoidance,
/// and presents as a centered spatial 3D dialog card on desktop screens (>= 650px).
Future<T?> showAppModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final isMobile = MediaQuery.sizeOf(context).width < 650;
  if (isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: const Color(0xFF141C2E).withValues(alpha: 0.45),
      builder: builder,
    );
  } else {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: const Color(0xFF141C2E).withValues(alpha: 0.45),
      builder: builder,
    );
  }
}

/// Unified modal surface that renders as a sleek bottom sheet on mobile
/// and a centered 3D surface card on desktop screens.
class AppModalCard extends StatelessWidget {
  const AppModalCard({
    required this.child,
    this.maxWidth = 480,
    this.maxHeight,
    this.padding = const EdgeInsets.fromLTRB(22, 10, 22, 22),
    this.showDragHandle = true,
    this.borderRadius = 20,
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;
  final double borderRadius;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 650;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    if (isMobile) {
      final sheetContent = Column(
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDragHandle)
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(top: 2, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DCE8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          if (scrollable)
            child
          else
            Expanded(child: child),
        ],
      );

      return Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight ?? (screenHeight * (scrollable ? 0.92 : 0.90)),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22141C2E),
              blurRadius: 32,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: scrollable
                ? SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: padding,
                      child: sheetContent,
                    ),
                  )
                : Padding(
                    padding: padding,
                    child: sheetContent,
                  ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? (!scrollable ? screenHeight * 0.90 : double.infinity),
        ),
        child: Surface3DCard(
          padding: padding,
          borderRadius: borderRadius,
          child: scrollable
              ? SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}
