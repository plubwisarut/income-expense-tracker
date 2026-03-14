import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createquest.dart';

class QuestDetailScreen extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> questData;

  const QuestDetailScreen({
    super.key,
    required this.questId,
    required this.questData,
  });

  String _iconPath(String category) {
    const map = {
      'น้ำหวาน/กาแฟ': 'assets/images/numwann.png',
      'ขนม/ของหวาน': 'assets/images/kanomwan.png',
      'เติมเกม': 'assets/images/termgame.png',
      'บันเทิง': 'assets/images/game.png',
      'เสื้อผ้า': 'assets/images/cloth.png',
      'เครื่องสำอาง': 'assets/images/sumang.png',
      'สกินแคร์': 'assets/images/skincare.png',
      'ช้อปปิ้ง': 'assets/images/shop.png',
      'สังสรรค์': 'assets/images/funny.png',
    };
    return map[category] ?? 'assets/images/other.png';
  }

  @override
  Widget build(BuildContext context) {
    final category = questData['category'] as String;
    final avgAmount = (questData['avgAmount'] as num).toInt();
    final totalSaved = (questData['totalSaved'] as num?)?.toInt() ?? 0;
    final checkInCount = (questData['checkInCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('งด$category'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: QuestService.progressStream(questId),
        builder: (context, snap) {
          List<String> checkedDates = [];

          if (snap.hasData && snap.data!.exists) {
            final pd = snap.data!.data() as Map<String, dynamic>;
            checkedDates =
                List<String>.from(pd['checkedInDates'] ?? []);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── Hero icon ──────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(_iconPath(category)),
                ),

                const SizedBox(height: 12),

                Text(
                  'งด$category',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  'งดได้วันไหน → +฿$avgAmount เข้าเป้าหมาย',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 24),

                // ─── Stats ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statBox('ได้วันละ', '฿$avgAmount', Colors.teal),
                    _statBox('งดแล้ว', '$checkInCount วัน',
                        Colors.blue),
                    _statBox(
                        'ออมได้รวม', '฿$totalSaved', Colors.amber.shade700),
                  ],
                ),

                const SizedBox(height: 28),

                // ─── Calendar ────────────────────────────────────────────
                if (checkedDates.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'วันที่งดได้',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: checkedDates.map((dateKey) {
                      // dateKey format: "2024-01-15"
                      final parts = dateKey.split('-');
                      final day = parts.length == 3 ? parts[2] : '?';
                      final month = parts.length == 3 ? parts[1] : '';

                      return Container(
                        width: 48,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '/$month',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 28),

                // ─── hint ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app,
                          color: Colors.teal.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'กด "งดแล้ว! 💪" ที่ banner หน้าหลักทุกวันที่งดได้ เงินจะเพิ่มเข้าเป้าหมายทันที',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.teal.shade700),
                        ),
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
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}