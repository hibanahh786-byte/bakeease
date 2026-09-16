import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  InvoiceScreen({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order['status'] != 'DELIVERED') {
      return Scaffold(
        appBar: AppBar(title: Text('Invoice')),
        body: Center(
          child: Text('Invoice is only available for DELIVERED orders.',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    final baker = order['baker']['user'];
    final items = order['items'] as List<dynamic>;

    Future<void> _printInvoice(BuildContext context) async {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text('BakeEase Official Invoice', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),
                pw.Text('From: BAKER ${baker['username']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Contact: ${baker['email']}'),
                pw.SizedBox(height: 20),
                pw.Text('To: CUSTOMER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Order Date: ${DateTime.parse(order['created_at']).toLocal().toString().substring(0, 16)}'),
                pw.SizedBox(height: 20),
                pw.Text('Order Items:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                ...items.map((item) {
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item['quantity']}x ${item['product']['name']} (${item['flavor'] ?? 'N/A'}, ${item['size'] ?? 'N/A'})'),
                      pw.Text('Rs. ${item['price']}'),
                    ]
                  );
                }).toList(),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount Paid', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${order['total_amount']}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.SizedBox(height: 40),
                pw.Center(child: pw.Text('Thank you for ordering with BakeEase!')),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'BakeEase_Invoice_${order['id']}.pdf',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${order['id']}'),
        actions: [
          IconButton(
            icon: Icon(Icons.print), 
            onPressed: () => _printInvoice(context)
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'BakeEase Official Invoice',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(thickness: 2),
            SizedBox(height: 10),
            Text('From: BAKER ${baker['username']}', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Contact: ${baker['email']}'),
            SizedBox(height: 20),
            Text('To: CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Order Date: ${DateTime.parse(order['created_at']).toLocal().toString().substring(0, 16)}'),
            SizedBox(height: 20),
            Text('Order Items:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text('${item['quantity']}x ${item['product']['name']}'),
                    subtitle: Text('Details: Flavor - ${item['flavor'] ?? 'N/A'}, Size - ${item['size'] ?? 'N/A'}'),
                    trailing: Text('₹${item['price']}', style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            Divider(thickness: 2),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Total Amount Paid', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   Text('₹${order['total_amount']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ]
              )
            ),
            SizedBox(height: 20),
            Center(child: Text('Thank you for ordering with BakeEase!', style: TextStyle(fontStyle: FontStyle.italic))),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
