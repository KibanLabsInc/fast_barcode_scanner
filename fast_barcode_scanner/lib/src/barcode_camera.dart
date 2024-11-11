import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ErrorCallback = Widget Function(BuildContext context, Object? error);

Widget _defaultOnError(BuildContext context, Object? error) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Center(
      child: Text(
        "Error:\n$error",
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

/// The main class connecting the platform code to the UI.
///
/// This class connects to the camera as soon as `didChangeDependencies` gets called.
class BarcodeCamera extends StatefulWidget {
  const BarcodeCamera({
    super.key,
    required this.types,
    this.mode = PerformanceMode.system,
    this.detectionMode = DetectionMode.pauseVideo,
    this.position = CameraPosition.back,
    this.api = const ApiMode(),
    this.onScan,
    this.children = const [],
    this.dispose = true,
    ErrorCallback? onError,
  }) : onError = onError ?? _defaultOnError;

  final List<BarcodeType> types;
  final PerformanceMode mode;
  final DetectionMode detectionMode;
  final CameraPosition position;
  final ApiMode api;
  final OnDetectionHandler? onScan;
  final List<Widget> children;
  final ErrorCallback onError;
  final bool dispose;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera> {
  var _opacity = 0.0;
  var showingError = false;

  final cameraController = CameraController.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final configurationFuture = cameraController.state.value.isInitialized
        ? cameraController.configure(
            types: widget.types,
            mode: widget.mode,
            position: widget.position,
            onScan: widget.onScan,
          )
        : cameraController.initialize(
            types: widget.types,
            mode: widget.mode,
            position: widget.position,
            detectionMode: widget.detectionMode,
            onScan: widget.onScan,
            api: widget.api,
          );

    configurationFuture
        .whenComplete(() => setState(() => _opacity = 1.0))
        .onError((error, stackTrace) => setState(() => showingError = true));

    cameraController.eventNotifier.addListener(onScannerEvent);
  }

  void onScannerEvent() {
    if (!mounted) return;

    if (cameraController.eventNotifier.value != ScannerEvent.error &&
        showingError) {
      setState(() => showingError = false);
    } else if (cameraController.eventNotifier.value == ScannerEvent.error) {
      setState(() => showingError = true);
    }
  }

  @override
  void dispose() {
    if (widget.dispose) {
      cameraController.dispose();
    } else {
      cameraController.pauseCamera();
    }

    cameraController.eventNotifier.removeListener(onScannerEvent);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = cameraController.state.value;

    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 250),
        child: cameraController.eventNotifier.value == ScannerEvent.error
            ? widget.onError(
                context,
                cameraState.error ?? "Unknown error occurred",
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraState.isInitialized)
                    _CameraPreview(
                        cameraInformation: cameraState.cameraInformation!),
                  ...widget.children
                ],
              ),
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.cameraInformation});

  final CameraInformation cameraInformation;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: cameraInformation.videoSize.height, // rotate to portrait
        height: cameraInformation.videoSize.width,
        child: Builder(
          builder: (_) {
            switch (defaultTargetPlatform) {
              // https://docs.flutter.dev/platform-integration/android/platform-views#texturelayerhybridcompisition
              case TargetPlatform.android:
                return const AndroidView(
                  viewType: "fast_barcode_scanner.preview",
                  creationParamsCodec: StandardMessageCodec(),
                );
              // return Texture(
              //   textureId: config.textureId,
              //   filterQuality: FilterQuality.none,
              // );
              case TargetPlatform.iOS:
                return const UiKitView(
                  viewType: "fast_barcode_scanner.preview",
                  creationParamsCodec: StandardMessageCodec(),
                );
              default:
                throw UnsupportedError("Unsupported platform");
            }
          },
        ),
      ),
    );
  }
}
