import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Front-camera preview scaled with [BoxFit.cover] inside a fixed square/circle.
///
/// Used by Face ID enrollment so the live feed appears only in the circular portal.
class FaceIdCircularCameraPreview extends StatelessWidget {
  const FaceIdCircularCameraPreview({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    // Camera plugin reports sensor size in landscape; swap for portrait UI.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }
}
