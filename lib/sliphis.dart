import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'auth_helper.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class SlipHistoryScreen extends StatelessWidget {
  const SlipHistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 42),
          const SizedBox(height: 12),
          const Text('ลบรายการ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('ลบ transaction นี้และสลิปที่แนบทั้งหมด\nไม่สามารถย้อนกลับได้',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ'),
            )),
          ]),
        ]),
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteTransaction(BuildContext context, QueryDocumentSnapshot doc) async {
    final confirmed = await _confirmDelete(context);
    if (!confirmed) return;

    // ลบไฟล์สลิปออกจาก device ด้วย
    final data = doc.data() as Map<String, dynamic>;
    final paths = List<String>.from(data['slipPaths'] ?? []);
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    await FirebaseFirestore.instance.collection('transactions').doc(doc.id).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('ลบรายการแล้ว'),
        backgroundColor: kPrimaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _viewImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(path)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: kText,
        title: const Text(
          'สลิปที่แนบไว้',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('userID', isEqualTo: AuthHelper.uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final paths = data['slipPaths'] as List<dynamic>?;
            return paths != null && paths.isNotEmpty;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long_outlined, size: 40, color: kPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text('ยังไม่มีสลิปที่แนบไว้',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('สลิปที่แนบตอนบันทึกรายการจะแสดงที่นี่',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final slipPaths = List<String>.from(data['slipPaths'] ?? []);
              final date = (data['date'] as Timestamp).toDate();
              final amount = data['amount'] as int;
              final category = data['category'] as String;
              final isExpense = data['type'] == 'expense';
              final note = data['note'] as String? ?? '';

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                ),
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => _deleteTransaction(context, doc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── header ──
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isExpense ? 'รายจ่าย' : 'รายรับ',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(category,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15, color: kText),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          '${isExpense ? '-' : '+'}฿$amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16,
                            color: isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ── ปุ่มลบ ──
                        GestureDetector(
                          onTap: () => _deleteTransaction(context, doc),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade400),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 4),

                      Row(children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('${date.day}/${date.month}/${date.year}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        if (note.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.notes_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(child: Text(note,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ]),

                      const SizedBox(height: 12),

                      Row(children: [
                        const Icon(Icons.image_outlined, size: 14, color: kPrimary),
                        const SizedBox(width: 4),
                        Text('สลิป ${slipPaths.length} รูป',
                            style: const TextStyle(
                                fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500)),
                      ]),

                      const SizedBox(height: 8),

                      // ── thumbnails ──
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: slipPaths.length,
                          itemBuilder: (context, i) {
                            final path = slipPaths[i];
                            final fileExists = path.isNotEmpty && File(path).existsSync();

                            return GestureDetector(
                              onTap: fileExists
                                  ? () => _viewImage(context, path)
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: fileExists
                                        ? kPrimary.withOpacity(0.2)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: fileExists
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: Image.file(File(path), fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_outlined,
                                              color: Colors.grey.shade400, size: 24),
                                          const SizedBox(height: 4),
                                          Text('ไม่พบไฟล์',
                                              style: TextStyle(
                                                  fontSize: 9, color: Colors.grey.shade400)),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}