// lib/screens/waybill_preview_screen.dart
//
// Shows the waybill rendered as an image scaled to fit the entire screen
// (no scrolling), with Print / Share / Download actions below.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/waybill_service.dart';

const Color _kPink = Color(0xFFFF4D8C);

class WaybillPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic>? shopInfo;

  const WaybillPreviewScreen({
    super.key,
    required this.order,
    this.shopInfo,
  });

  @override
  State<WaybillPreviewScreen> createState() => _WaybillPreviewScreenState();
}

class _WaybillPreviewScreenState extends State<WaybillPreviewScreen> {
  Uint8List? _pdfBytes;
  Uint8List? _imageBytes;
  String? _error;

  static const PdfPageFormat _format =
      PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch);

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await WaybillService.buildBytes(
        order: widget.order,
        shopInfo: widget.shopInfo,
      );
      final pdfBytes = Uint8List.fromList(bytes);

      // Render the first page as an image (~200 dpi) for crisp preview.
      Uint8List? imgBytes;
      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        imgBytes = await page.toPng();
        break;
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = pdfBytes;
        _imageBytes = imgBytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _print() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(
      name:
          'Waybill-${widget.order['tracking_number'] ?? widget.order['id'] ?? 'order'}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _share() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Waybill-${widget.order['tracking_number'] ?? widget.order['id'] ?? 'order'}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = widget.order['tracking_number']?.toString() ?? 'Waybill';

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: _kPink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Waybill',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(tracking,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview area — fills available space, image scales to fit.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _error != null
                      ? Text(
                          'Failed to render waybill:\n$_error',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        )
                      : _imageBytes == null
                          ? const CircularProgressIndicator(color: _kPink)
                          : InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4,
                              child: AspectRatio(
                                aspectRatio:
                                    _format.width / _format.height, // 4:6
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
            ),

            // Action bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      color: Colors.grey.shade100,
                      iconColor: Colors.black87,
                      textColor: Colors.black87,
                      onTap: _imageBytes == null ? null : _share,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.download_rounded,
                      label: 'Download',
                      color: Colors.grey.shade100,
                      iconColor: Colors.black87,
                      textColor: Colors.black87,
                      onTap: _imageBytes == null ? null : _share,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _ActionButton(
                      icon: Icons.print_rounded,
                      label: 'Print',
                      color: _kPink,
                      iconColor: Colors.white,
                      textColor: Colors.white,
                      onTap: _imageBytes == null ? null : _print,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? color.withOpacity(0.4) : color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
