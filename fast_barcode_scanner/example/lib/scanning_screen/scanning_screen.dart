import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:flutter/material.dart';

import '../configure_screen/configure_screen.dart';
import '../scan_history.dart';
import '../utils.dart';
import 'scans_counter.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({
    super.key,
    this.apiMode = const ApiMode(),
    required this.dispose,
  });

  final ApiMode apiMode;
  final bool dispose;

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final _torchIconState = ValueNotifier(false);
  final _cameraRunning = ValueNotifier(true);
  final _scannerRunning = ValueNotifier(true);

  bool _isShowingBottomSheet = false;

  final greenPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..color = Colors.green;

  final orangePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.bevel
    ..color = Colors.orange;

  final availableOverlays = ["Boundary", "Material", "Blur"];

  var enabledOverlays = [
    "Material",
    "Boundary",
  ];

  final cam = CameraController.shared;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Fast Barcode Scanner',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              final preview = cam.state.value.cameraInformation;

              if (preview != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Preview Config"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(preview.toString())],
                    ),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: BarcodeCamera(
        types: const [
          BarcodeType.ean8,
          BarcodeType.ean13,
          BarcodeType.code128,
          BarcodeType.qr,
        ],
        mode: PerformanceMode.system,
        detectionMode: DetectionMode.continuous,
        position: CameraPosition.back,
        api: widget.apiMode,
        onScan: (code) {
          history.addAll(code);
        },
        dispose: widget.dispose,
        children: [
          if (enabledOverlays.contains("Material"))
            MaterialPreviewOverlay(
              rectOfInterest: RectOfInterest.wide(),
              onScan: (codes) {},
              showSensing: true,
              onScannedBoundsColor: (codes) {
                if (codes.isNotEmpty) {
                  return codes.first.value.hashCode % 2 == 0
                      ? Colors.orange
                      : Colors.green;
                }
                return null;
              },
            ),
          if (enabledOverlays.contains(("Boundary")))
            CodeBoundaryOverlay(
              codeBorderPaintBuilder: (code) {
                return code.value.hashCode % 2 == 0 ? orangePaint : greenPaint;
              },
              barcodeValueStyle: (code) => TextStyle(
                color:
                    code.value.hashCode % 2 == 0 ? Colors.orange : Colors.green,
              ),
            ),
          if (enabledOverlays.contains("Blur")) const BlurPreviewOverlay()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isShowingBottomSheet = !_isShowingBottomSheet;
          });
        },
        child: Icon(_isShowingBottomSheet ? Icons.close : Icons.settings),
      ),
      bottomSheet: _isShowingBottomSheet
          ? SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScansCounter(),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            ValueListenableBuilder<bool>(
                                valueListenable: _cameraRunning,
                                builder: (context, isRunning, _) {
                                  return ElevatedButton(
                                    onPressed: () {
                                      final future = isRunning
                                          ? cam.pauseCamera()
                                          : cam.resumeCamera();

                                      future.then((_) {
                                        _cameraRunning.value = !isRunning;
                                      }).catchError((error, stack) {
                                        presentErrorAlert(
                                          context,
                                          error,
                                          stack,
                                        );
                                      });
                                    },
                                    child: Text(isRunning
                                        ? 'Pause Camera'
                                        : 'Resume Camera'),
                                  );
                                }),
                            ValueListenableBuilder<bool>(
                                valueListenable: _scannerRunning,
                                builder: (context, isRunning, _) {
                                  return ElevatedButton(
                                    onPressed: () {
                                      final future = isRunning
                                          ? cam.pauseScanner()
                                          : cam.resumeScanner();

                                      future.then((_) {
                                        _scannerRunning.value = !isRunning;
                                      }).catchError((error, stackTrace) {
                                        presentErrorAlert(
                                          context,
                                          error,
                                          stackTrace,
                                        );
                                      });
                                    },
                                    child: Text(isRunning
                                        ? 'Pause Scanner'
                                        : 'Resume Scanner'),
                                  );
                                }),
                            ValueListenableBuilder<bool>(
                              valueListenable: _torchIconState,
                              builder: (context, isTorchActive, _) =>
                                  ElevatedButton(
                                onPressed: () {
                                  cam.toggleTorch().then((torchState) {
                                    _torchIconState.value = torchState;
                                  }).catchError((error, stackTrace) {
                                    presentErrorAlert(
                                      context,
                                      error,
                                      stackTrace,
                                    );
                                  });
                                },
                                child: Text(
                                    'Torch: ${isTorchActive ? 'on' : 'off'}'),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final config = cam.state.value.scannerConfig;
                                if (config != null) {
                                  // swallow errors
                                  cam.pauseCamera().catchError((_, __) {});

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ConfigureScreen(),
                                    ),
                                  );

                                  cam.resumeCamera().catchError(
                                        (error, stack) => presentErrorAlert(
                                            context, error, stack),
                                      );
                                }
                              },
                              child: const Text('Update Configuration'),
                            )
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
