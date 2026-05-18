// lib/services/waybill_service.dart
//
// Generates a printable shipping waybill (PDF) for an order.
// The waybill includes:
//   • Sender (shop / business) block
//   • Recipient (buyer) block
//   • A Code-128 barcode of the tracking number (scannable by couriers)
//   • A QR code with the full tracking URL (scannable for tracking)
//   • Order summary, item count, weight, COD amount, courier, date
//
// The generated PDF is opened in the system print/share sheet via the
// `printing` package, so it can be sent to a real printer (USB, AirPrint,
// network) or saved/shared as a PDF.

import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class WaybillService {
  /// Builds the waybill PDF and immediately opens the print/share dialog.
  static Future<void> printWaybill({
    required Map<String, dynamic> order,
    Map<String, dynamic>? shopInfo,
  }) async {
    final pdf = await _buildPdf(order: order, shopInfo: shopInfo);
    await Printing.layoutPdf(
      name:
          'Waybill-${order['tracking_number'] ?? order['id'] ?? 'order'}.pdf',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Returns the raw PDF bytes (useful if you want to save / upload).
  static Future<List<int>> buildBytes({
    required Map<String, dynamic> order,
    Map<String, dynamic>? shopInfo,
  }) async {
    final pdf = await _buildPdf(order: order, shopInfo: shopInfo);
    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Internal builder
  // ───────────────────────────────────────────────────────────────────────
  static Future<pw.Document> _buildPdf({
    required Map<String, dynamic> order,
    Map<String, dynamic>? shopInfo,
  }) async {
    final pdf = pw.Document();

    // Use a Unicode-capable font so peso sign (₱) renders correctly.
    pw.Font? unicodeFont;
    pw.Font? unicodeBold;
    try {
      unicodeFont = pw.Font.helvetica();
      unicodeBold = pw.Font.helveticaBold();
    } catch (_) {
      // Fallback to defaults
    }

    final tracking =
        (order['tracking_number']?.toString() ?? '').trim().isEmpty
            ? 'NO-TRACKING'
            : order['tracking_number'].toString();
    final courier = order['courier']?.toString() ?? 'COURIER';
    final shortId = (order['id']?.toString() ?? '')
        .replaceAll('-', '')
        .padRight(8, '0')
        .substring(0, 8)
        .toUpperCase();

    final buyerName = order['buyer_name']?.toString() ?? 'Buyer';
    final buyerPhone = order['buyer_phone']?.toString() ?? '';
    final buyerAddr = [
      order['shipping_address'],
      order['shipping_city'],
      order['shipping_postal_code'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final items = List<Map<String, dynamic>>.from(
        order['order_items'] as List? ?? const []);
    final totalQty = items.fold<int>(
        0, (s, it) => s + ((it['quantity'] as num?)?.toInt() ?? 0));
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final currency = order['currency']?.toString() ?? 'PHP';
    final paymentMethod =
        (order['payment_method']?.toString() ?? '').toUpperCase();
    final isCOD = paymentMethod.contains('COD') ||
        paymentMethod.contains('CASH');

    final shopName = shopInfo?['business_name']?.toString() ??
        shopInfo?['name']?.toString() ??
        'FaceTuneBeauty Shop';
    final shopPhone = shopInfo?['phone']?.toString() ?? '';
    final shopAddr = shopInfo?['address']?.toString() ?? '';

    final dateStr = DateTime.now().toLocal().toString().substring(0, 16);

    // Generate barcode SVG strings.
    final code128 = bc.Barcode.code128();
    final code128Svg = code128.toSvg(tracking, width: 260, height: 50);

    final qr = bc.Barcode.qrCode();
    final qrSvg = qr.toSvg(
      'https://facetunebeauty.app/track/$tracking',
      width: 80,
      height: 80,
    );

    pdf.addPage(
      pw.Page(
        // Standard 4x6 inch shipping label (101.6mm x 152.4mm) —
        // the format used by J&T, LBC, Ninja Van, Flash Express, SPX, etc.
        pageFormat:
            const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch,
                marginAll: 6),
        margin: const pw.EdgeInsets.all(6),
        build: (ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── Header: courier + COD badge ─────────────────────────
                pw.Container(
                  color: PdfColors.black,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        courier.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          font: unicodeBold,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: pw.BoxDecoration(
                          color: isCOD ? PdfColors.amber : PdfColors.green300,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          isCOD ? 'COD' : 'PAID',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: unicodeBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tracking barcode ────────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SvgImage(svg: code128Svg),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        tracking,
                        style: pw.TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: pw.FontWeight.bold,
                          font: unicodeBold,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Divider(height: 1, color: PdfColors.black),

                // ── Sender / Recipient ──────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: _addressBlock(
                          label: 'FROM',
                          name: shopName,
                          phone: shopPhone,
                          address: shopAddr.isEmpty
                              ? 'Address on file'
                              : shopAddr,
                          font: unicodeFont,
                          bold: unicodeBold,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Expanded(
                        child: _addressBlock(
                          label: 'TO',
                          name: buyerName,
                          phone: buyerPhone,
                          address: buyerAddr.isEmpty
                              ? 'Address on file'
                              : buyerAddr,
                          font: unicodeFont,
                          bold: unicodeBold,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Divider(height: 1, color: PdfColors.black),

                // ── Order details + QR ──────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _detailRow('Order #', shortId, unicodeFont, unicodeBold),
                            _detailRow('Date', dateStr, unicodeFont, unicodeBold),
                            _detailRow('Items', '$totalQty pcs', unicodeFont, unicodeBold),
                            _detailRow('Payment', paymentMethod.isEmpty ? 'N/A' : paymentMethod, unicodeFont, unicodeBold),
                            _detailRow(
                              isCOD ? 'COD Amount' : 'Total',
                              '$currency ${total.toStringAsFixed(2)}',
                              unicodeFont,
                              unicodeBold,
                              highlight: isCOD,
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 80,
                        height: 80,
                        padding: const pw.EdgeInsets.all(2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black),
                        ),
                        child: pw.SvgImage(svg: qrSvg),
                      ),
                    ],
                  ),
                ),

                pw.Divider(height: 1, color: PdfColors.black),

                // ── Item list ───────────────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CONTENTS',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                          font: unicodeBold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      ...items.take(4).map((it) {
                        final name = it['product_name']?.toString() ?? 'Item';
                        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                        final variation = it['variation_name']?.toString();
                        final label = variation != null && variation.isNotEmpty
                            ? '$name ($variation)'
                            : name;
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  label,
                                  style: pw.TextStyle(
                                      fontSize: 8, font: unicodeFont),
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                              pw.Text(
                                'x$qty',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    font: unicodeBold),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (items.length > 4)
                        pw.Text(
                          '... +${items.length - 4} more',
                          style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey600,
                              font: unicodeFont),
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // ── Footer ──────────────────────────────────────────────
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'FaceTuneBeauty • Handle with care',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                            font: unicodeFont),
                      ),
                      pw.Text(
                        'Scan QR to track',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                            font: unicodeFont),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  static pw.Widget _addressBlock({
    required String label,
    required String name,
    required String phone,
    required String address,
    pw.Font? font,
    pw.Font? bold,
    bool highlight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: highlight ? PdfColors.grey100 : null,
        border: pw.Border.all(
            color: highlight ? PdfColors.black : PdfColors.grey400, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              font: bold,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              font: bold,
            ),
            maxLines: 2,
          ),
          if (phone.isNotEmpty)
            pw.Text(
              phone,
              style: pw.TextStyle(fontSize: 8, font: font),
            ),
          pw.SizedBox(height: 1),
          pw.Text(
            address,
            style: pw.TextStyle(fontSize: 8, font: font),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  static pw.Widget _detailRow(
    String label,
    String value,
    pw.Font? font,
    pw.Font? bold, {
    bool highlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey700, font: font),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: highlight ? 10 : 8,
                fontWeight: pw.FontWeight.bold,
                color: highlight ? PdfColors.red : PdfColors.black,
                font: bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
