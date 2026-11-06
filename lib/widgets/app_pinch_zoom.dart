import 'package:flutter/material.dart';

/// Shared visual magnification for every route, dialog and app control.
/// Nested image viewers retain their own scale gesture through Flutter's arena.
class AppPinchZoom extends StatefulWidget {
  final Widget child;
  const AppPinchZoom({super.key, required this.child});

  @override
  State<AppPinchZoom> createState() => _AppPinchZoomState();
}

class _AppPinchZoomState extends State<AppPinchZoom> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      InteractiveViewer(
        key: const ValueKey('app-pinch-viewer'),
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        clipBehavior: Clip.hardEdge,
        child: widget.child,
      ),
      ValueListenableBuilder<Matrix4>(
        valueListenable: _transform,
        builder: (context, matrix, _) {
          final scale = matrix.getMaxScaleOnAxis();
          if (scale <= 1.01) return const SizedBox.shrink();
          return PositionedDirectional(
            end: 12,
            top: MediaQuery.paddingOf(context).top + 64,
            child: Semantics(
              label: '화면 배율 초기화',
              button: true,
              child: FilledButton.tonalIcon(
                key: const ValueKey('app-pinch-reset'),
                onPressed: () => _transform.value = Matrix4.identity(),
                icon: const Icon(Icons.zoom_out_map),
                label: Text('${(scale * 100).round()}% → 100%'),
              ),
            ),
          );
        },
      ),
    ]);
  }
}
