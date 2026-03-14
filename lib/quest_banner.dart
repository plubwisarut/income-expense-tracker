import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createquest.dart';

class QuestBannerList extends StatelessWidget {
  final String? activeGoalId;

  const QuestBannerList({super.key, required this.activeGoalId});

  @override
  Widget build(BuildContext context) {
    if (activeGoalId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: QuestService.activeQuestsStream(activeGoalId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final quests = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...quests.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] as String;

              if (type == 'daily') {
                return _DailyBanner(
                  questId: doc.id,
                  data: data,
                  goalId: activeGoalId!,
                );
              } else if (type == 'limit') {
                return _LimitBanner(
                  questId: doc.id,
                  data: data,
                );
              } else if (type == 'self_compare') {
                return _SelfCompareBanner(
                  questId: doc.id,
                  data: data,
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

// ─── Daily Banner (เดิม) ───────────────────────────────────────────────────
class _DailyBanner extends StatefulWidget {
  final String questId;
  final Map<String, dynamic> data;
  final String goalId;

  const _DailyBanner({
    required this.questId,
    required this.data,
    required this.goalId,
  });

  @override
  State<_DailyBanner> createState() => _DailyBannerState();
}

class _DailyBannerState extends State<_DailyBanner> {
  bool _loading = false;

  String _iconPath(String category) {
    const map = {
      'น้ำหวาน/กาแฟ': 'assets/images/numwann.png',
      'ขนม/ของหวาน': 'assets/images/kanomwan.png',
      'เติมเกม': 'assets/images/termgame.png',
      'บันเทิง': 'assets/images/game.png',
    };
    return map[category] ?? 'assets/images/other.png';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onCheckIn(int avgAmount) async {
    setState(() => _loading = true);

    final result = await QuestService.checkInDaily(
      widget.questId,
      avgAmount,
      widget.goalId,
    );

    setState(() => _loading = false);
    if (!mounted) return;

    switch (result) {
      case CheckInResult.success:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ งดได้! +฿$avgAmount เข้าเป้าหมายแล้ว'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ));
        break;
      case CheckInResult.alreadyChecked:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Check-in วันนี้ไปแล้ว'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        break;
      case CheckInResult.error:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        break;
    }
  }

  Future<void> _onSkip() async {
    await FirebaseFirestore.instance
        .collection('questProgress')
        .doc(widget.questId)
        .set({
      'skippedDates': FieldValue.arrayUnion([_todayKey()]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.data['category'] as String;
    final avgAmount = widget.data['avgAmount'] as int;
    final checkInCount =
        (widget.data['checkInCount'] as num?)?.toInt() ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: QuestService.progressStream(widget.questId),
      builder: (context, snap) {
        List<String> skippedDates = [];
        List<String> checkedDates = [];

        if (snap.hasData && snap.data!.exists) {
          final pd = snap.data!.data() as Map<String, dynamic>;
          skippedDates = List<String>.from(pd['skippedDates'] ?? []);
          checkedDates = List<String>.from(pd['checkedInDates'] ?? []);
        }

        final today = _todayKey();
        final checkedToday = checkedDates.contains(today);
        final skippedToday = skippedDates.contains(today);

        if (skippedToday || checkedToday) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                '🎯 ภารกิจวันนี้',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFED820E), Color(0xFFED820E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(_iconPath(category),
                              width: 36, height: 36),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'วันนี้งด$category ได้ไหม?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (checkInCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🔥 $checkInCount วัน',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'งดได้ → +฿$avgAmount เข้าเป้าหมายทันที',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white38),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loading ? null : _onSkip,
                            child: const Text('ไม่งด'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFED820E),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _loading
                                ? null
                                : () => _onCheckIn(avgAmount),
                            child: _loading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.teal.shade700,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'งดแล้ว! 💪',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Limit Banner (เดิม) ───────────────────────────────────────────────────
class _LimitBanner extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> data;

  const _LimitBanner({required this.questId, required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String;
    final targetCount = data['targetCount'] as int;
    final avgAmount = data['avgAmount'] as int;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final potentialSaving =
        ((data['currentCount'] as int) - targetCount) * avgAmount;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .snapshots(),
      builder: (context, snap) {
        final usedCount = snap.hasData ? snap.data!.docs.length : 0;
        final isOnTrack = usedCount <= targetCount;
        final remaining = (targetCount - usedCount).clamp(0, targetCount);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isOnTrack ? Colors.blue.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOnTrack
                  ? Colors.blue.shade200
                  : Colors.orange.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnTrack
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: isOnTrack ? Colors.blue : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ลด$category เหลือ $targetCount ครั้ง/เดือน',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      isOnTrack
                          ? 'ใช้ไป $usedCount/$targetCount ครั้ง · เหลืออีก $remaining ครั้ง'
                          : 'เกินเป้า! ใช้ไป $usedCount ครั้ง',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnTrack
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      'ประหยัดได้ถึง ฿$potentialSaving สิ้นเดือนนี้',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Self Compare Banner (ใหม่) ────────────────────────────────────────────
class _SelfCompareBanner extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> data;

  const _SelfCompareBanner({required this.questId, required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String;
    final targetAmount = data['targetAmount'] as int;
    final monthlyAvg = data['monthlyAvg'] as int;
    final successCount = (data['successCount'] as num?)?.toInt() ?? 0;
    final lastResult = data['lastMonthResult'] as Map<String, dynamic>?;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .snapshots(),
      builder: (context, snap) {
        final usedAmount = snap.hasData
            ? snap.data!.docs
                .fold<int>(0, (s, d) => s + (d['amount'] as num).toInt())
            : 0;

        final isOnTrack = usedAmount <= targetAmount;
        final progress = targetAmount > 0
            ? (usedAmount / targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final remaining = targetAmount - usedAmount;
        final savedSoFar = monthlyAvg - usedAmount;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOnTrack
                  ? Colors.purple.shade200
                  : Colors.red.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.compare_arrows,
                        color: Colors.purple.shade400, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ใช้$categoryให้น้อยกว่าเดิม',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'เป้า: ≤฿$targetAmount (เดิมเฉลี่ย ฿$monthlyAvg/เดือน)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  if (successCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✨ $successCount เดือน',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOnTrack ? Colors.purple.shade400 : Colors.red.shade400,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── status row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ใช้ไปแล้ว ฿$usedAmount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOnTrack
                          ? Colors.purple.shade700
                          : Colors.red.shade600,
                    ),
                  ),
                  Text(
                    isOnTrack
                        ? 'เหลืออีก ฿$remaining · $daysLeft วันสุดท้าย'
                        : 'เกินเป้า ฿${remaining.abs()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnTrack
                          ? Colors.grey.shade500
                          : Colors.red.shade400,
                    ),
                  ),
                ],
              ),

              // ── ถ้ากำลังประหยัดได้อยู่ ──
              if (isOnTrack && savedSoFar > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎉 ถ้าสิ้นเดือนนี้ยังทำได้ จะประหยัดได้ ฿$savedSoFar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // ── ผลเดือนที่แล้ว ──
              if (lastResult != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (lastResult['success'] as bool)
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (lastResult['success'] as bool)
                        ? '✅ เดือนที่แล้ว: ประหยัดได้ ฿${lastResult['savedAmount']}'
                        : '❌ เดือนที่แล้ว: ใช้เกินไป ฿${(lastResult['actualAmount'] as int) - targetAmount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: (lastResult['success'] as bool)
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Habit Banner (ใหม่) ───────────────────────────────────────────────────
class _HabitBanner extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> data;
  final String goalId;

  const _HabitBanner({
    required this.questId,
    required this.data,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context) {
    final targetDays = (data['targetDays'] as num?)?.toInt() ?? 7;
    final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;
    final completedCount = (data['completedCount'] as num?)?.toInt() ?? 0;

    final progress = currentStreak / targetDays;
    final remaining = targetDays - currentStreak;

    return StreamBuilder<DocumentSnapshot>(
      stream: QuestService.progressStream(questId),
      builder: (context, snap) {
        List<String> recordedDates = [];
        if (snap.hasData && snap.data!.exists) {
          final pd = snap.data!.data() as Map<String, dynamic>;
          recordedDates =
              List<String>.from(pd['recordedDates'] ?? []);
        }

        final today =
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
        final recordedToday = recordedDates.contains(today);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: recordedToday
                  ? Colors.teal.shade300
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_note,
                        color: Colors.teal.shade500, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'บันทึกรายจ่ายทุกวัน',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'บันทึกให้ครบ $targetDays วันติดต่อกัน',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  if (recordedToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✅ วันนี้แล้ว',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── dot progress ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(targetDays, (i) {
                  final isDone = i < currentStreak;
                  final isToday = i == currentStreak && recordedToday;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDone || isToday
                            ? Colors.teal
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 8),

              // ── status ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentStreak > 0
                        ? '🔥 streak $currentStreak วัน'
                        : 'เริ่มบันทึกวันนี้เลย!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: currentStreak > 0
                          ? Colors.teal.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    remaining > 0
                        ? 'อีก $remaining วันจะครบ!'
                        : '🎊 ครบแล้ว!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),

              // ── สถิติ ──
              if (completedCount > 0 || longestStreak > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (completedCount > 0)
                      _statChip(
                          '🏆 ทำครบแล้ว $completedCount รอบ',
                          Colors.amber.shade50,
                          Colors.amber.shade700),
                    if (completedCount > 0 && longestStreak > 0)
                      const SizedBox(width: 6),
                    if (longestStreak > 0)
                      _statChip(
                          '⚡ สูงสุด $longestStreak วัน',
                          Colors.teal.shade50,
                          Colors.teal.shade700),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, Color bg, Color text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: text,
                fontWeight: FontWeight.w600)),
      );
}