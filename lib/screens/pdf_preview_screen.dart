import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/models.dart';
import '../core/statement_pdf.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Shows the statement inside the app, with a send button.
class PdfPreviewScreen extends StatelessWidget {
  final Person person;
  final String ownerName;
  const PdfPreviewScreen({super.key, required this.person, required this.ownerName});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب ${person.name}')),
      body: PdfPreview(
        build: (_) => StatementPdf.build(person, ownerName: ownerName),
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: StatementPdf.fileName(person),
        scrollViewDecoration: BoxDecoration(color: p.bg),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18)],
        ),
        loadingWidget: Center(child: CircularProgressIndicator(color: p.gold)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(children: [
            Expanded(
              child: GhostButton(
                label: 'حفظ',
                icon: Icons.download_rounded,
                onPressed: () async {
                  final ok = await StatementPdf.saveToDevice(person, ownerName: ownerName);
                  if (ok && context.mounted) toast(context, 'تم حفظ الملف');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GoldButton(
                label: 'إرسال',
                icon: Icons.send_rounded,
                onPressed: () => StatementPdf.share(person, ownerName: ownerName),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
