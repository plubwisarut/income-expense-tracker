import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createquest.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class QuestScreen extends StatelessWidget {
  final String goalId;
  final String goalTitle;

  const QuestScreen({
    super.key,
    required this.goalId,
    required this.goalTitle,
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
      'อาหาร': 'assets/images/food.png',
      'เดินทาง': 'assets/images/travel.png',
      'บันทึกรายจ่าย': 'assets/images/other.png',
    };
    return map[category] ?? 'assets/images/other.png';
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
        title: Text(
          'ภารกิจ · $goalTitle',
          style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: QuestService.allQuestsStream(goalId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }

          final quests = snapshot.data!.docs
              .where((d) => d['status'] != 'cancelled')
              .toList();

          if (quests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_outlined, size: 40, color: kPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text('ยังไม่มีภารกิจ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('ใช้จ่ายในหมวดฟุ่มเฟือยบ่อยๆ\nระบบจะสร้างภารกิจให้อัตโนมัติ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, height: 1.6, fontSize: 14)),
                ],
              ),
            );
          }

          final dailyQuests = quests.where((d) => d['type'] == 'daily').toList();
          final autoQuests = quests.where((d) => d['type'] != 'daily').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── section: งดรายวัน (มี toggle) ──
              if (dailyQuests.isNotEmpty) ...[
                _sectionHeader(
                  icon: '🚫',
                  title: 'งดรายวัน',
                  color: const Color(0xFFED820E),
                  description: 'เปิดภารกิจที่อยากทำ กดยืนยันทุกวันที่งดได้',
                ),
                const SizedBox(height: 10),
                ...dailyQuests.map((doc) => _DailyQuestCard(
                  doc: doc,
                  iconPath: _iconPath(doc['category'] as String),
                )),
                const SizedBox(height: 20),
              ],

              // ── section: ภารกิจเสริม (อัตโนมัติ ไม่มี toggle) ──
              if (autoQuests.isNotEmpty) ...[
                _sectionHeader(
                  icon: '⚙️',
                  title: 'ภารกิจเสริม',
                  color: kPrimaryDark,
                  description: 'ระบบติดตามให้อัตโนมัติ ไม่ต้องกดอะไร',
                ),
                const SizedBox(height: 10),
                ...autoQuests.map((doc) => _AutoQuestCard(
                  doc: doc,
                  iconPath: _iconPath(doc['category'] as String),
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader({
    required String icon,
    required String title,
    required Color color,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$icon $title',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ─── Daily Quest Card (มี toggle) ─────────────────────────────────────────
class _DailyQuestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String iconPath;

  const _DailyQuestCard({required this.doc, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] as String;
    final avgAmount = (data['avgAmount'] as num?)?.toInt() ?? 0;
    final isActive = data['status'] == 'active';
    final totalSaved = (data['totalSaved'] as num?)?.toInt() ?? 0;
    final checkInCount = (data['checkInCount'] as num?)?.toInt() ?? 0;
    const color = Color(0xFFED820E);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.35) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: isActive ? color.withOpacity(0.08) : Colors.black.withOpacity(0.03),
          blurRadius: isActive ? 10 : 6, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(iconPath, width: 36, height: 36,
                color: isActive ? null : Colors.grey,
                colorBlendMode: isActive ? null : BlendMode.saturation),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('งด$category',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: isActive ? kText : Colors.grey)),
              const SizedBox(height: 3),
              Text('งดได้ → +฿$avgAmount/วัน',
                  style: TextStyle(fontSize: 12,
                      color: isActive ? color : Colors.grey.shade400,
                      fontWeight: FontWeight.w500)),
              if (isActive && checkInCount > 0) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('งดแล้ว $checkInCount วัน · ออมได้ ฿$totalSaved',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          )),
          Switch(
            value: isActive,
            activeColor: color,
            onChanged: (val) => QuestService.toggleQuest(doc.id, val),
          ),
        ]),
      ),
    );
  }
}

// ─── Auto Quest Card (ไม่มี toggle, แสดงสถานะ) ────────────────────────────
class _AutoQuestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String iconPath;

  const _AutoQuestCard({required this.doc, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String;
    final category = data['category'] as String;

    switch (type) {
      case 'habit':
        return _HabitAutoCard(data: data);
      case 'self_compare':
        return _SelfCompareAutoCard(questId: doc.id, data: data);
      case 'limit':
        return _LimitAutoCard(questId: doc.id, data: data, iconPath: iconPath);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Habit Auto Card ───────────────────────────────────────────────────────
class _HabitAutoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HabitAutoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final targetDays = (data['targetDays'] as num?)?.toInt() ?? 7;
    final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
    final completedCount = (data['completedCount'] as num?)?.toInt() ?? 0;

    return _AutoCardShell(
      color: Colors.teal,
      icon: Image.asset('assets/images/dailycheck.png', width: 36, height: 36),
      iconBg: Colors.teal.shade50,
      title: 'บันทึกรายจ่ายทุกวัน',
      subtitle: 'บันทึกให้ครบ $targetDays วันติดต่อกัน',
      badge: 'นิสัยดี',
      badgeColor: Colors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(targetDays, (i) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                decoration: BoxDecoration(
                  color: i < currentStreak ? Colors.teal : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            )),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.local_fire_department, size: 14,
                color: currentStreak > 0 ? Colors.orange : Colors.grey.shade300),
            const SizedBox(width: 4),
            Text(
              currentStreak > 0 ? 'streak $currentStreak/$targetDays วัน' : 'เริ่มบันทึกวันนี้เลย!',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: currentStreak > 0 ? Colors.orange.shade700 : Colors.grey.shade400),
            ),
            const Spacer(),
            if (completedCount > 0)
              _chip('🏆 ครบ $completedCount รอบ', Colors.teal.shade50, Colors.teal.shade700),
          ]),

        ],
      ),
    );
  }
}

// ─── Self Compare Auto Card ────────────────────────────────────────────────
class _SelfCompareAutoCard extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> data;
  const _SelfCompareAutoCard({required this.questId, required this.data});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String;
    final monthlyAvg = (data['monthlyAvg'] as num?)?.toInt() ?? 0;
    final targetAmount = (data['targetAmount'] as num?)?.toInt() ?? 0;
    final successCount = (data['successCount'] as num?)?.toInt() ?? 0;
    final totalSaved = (data['totalSaved'] as num?)?.toInt() ?? 0;
    final lastResult = data['lastMonthResult'] as Map<String, dynamic>?;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .snapshots(),
      builder: (context, snap) {
        final usedAmount = snap.hasData
            ? snap.data!.docs.fold<int>(0, (s, d) => s + (d['amount'] as num).toInt())
            : 0;
        final isOnTrack = usedAmount <= targetAmount;
        final progress = targetAmount > 0 ? (usedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

        return _AutoCardShell(
          color: Colors.purple,
          icon: Image.asset('assets/images/downbill.png', width: 36, height: 36),
          iconBg: Colors.purple.shade50,
          title: 'ใช้$categoryให้น้อยกว่าเดิม',
          subtitle: 'เป้า ≤฿$targetAmount/เดือน (เดิม ฿$monthlyAvg)',
          badge: 'พัฒนาตัวเอง',
          badgeColor: Colors.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isOnTrack ? Colors.purple.shade400 : Colors.red.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('฿$usedAmount / ฿$targetAmount',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: isOnTrack ? Colors.purple.shade600 : Colors.red.shade500)),
              ]),
              if (totalSaved > 0 || successCount > 0) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  if (totalSaved > 0)
                    _chip('💰 ออมได้รวม ฿$totalSaved', Colors.amber.shade50, Colors.amber.shade700),
                  if (successCount > 0)
                    _chip('✨ สำเร็จ $successCount เดือน', Colors.purple.shade50, Colors.purple.shade700),
                ]),
              ],
              if (lastResult != null) ...[
                const SizedBox(height: 4),
                Text(
                  (lastResult['success'] as bool)
                      ? '✅ เดือนที่แล้ว: ประหยัด ฿${lastResult['savedAmount']}'
                      : '❌ เดือนที่แล้ว: เกินเป้า',
                  style: TextStyle(fontSize: 11,
                      color: (lastResult['success'] as bool)
                          ? Colors.green.shade600 : Colors.orange.shade600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Limit Auto Card ───────────────────────────────────────────────────────
class _LimitAutoCard extends StatelessWidget {
  final String questId;
  final Map<String, dynamic> data;
  final String iconPath;
  const _LimitAutoCard({required this.questId, required this.data, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String;
    final targetCount = (data['targetCount'] as num?)?.toInt() ?? 0;
    final currentCount = (data['currentCount'] as num?)?.toInt() ?? 0;
    final totalSaved = (data['totalSaved'] as num?)?.toInt() ?? 0;
    final lastResult = data['lastMonthResult'] as Map<String, dynamic>?;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .snapshots(),
      builder: (context, snap) {
        final usedCount = snap.hasData ? snap.data!.docs.length : 0;
        final isOnTrack = usedCount <= targetCount;
        final progress = targetCount > 0 ? (usedCount / targetCount).clamp(0.0, 1.0) : 0.0;

        return _AutoCardShell(
          color: Colors.blue,
          icon: Image.asset(iconPath, width: 36, height: 36),
          iconBg: Colors.blue.shade50,
          title: 'ลด$categoryให้น้อยลง',
          subtitle: 'เป้าหมาย ≤$targetCount ครั้ง/เดือน (เดิม $currentCount ครั้ง)',
          badge: '🎯 จำกัดครั้ง',
          badgeColor: Colors.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isOnTrack ? Colors.blue.shade400 : Colors.red.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$usedCount/$targetCount ครั้ง',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: isOnTrack ? Colors.blue.shade600 : Colors.red.shade500)),
              ]),
              if (totalSaved > 0 || lastResult != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  if (totalSaved > 0)
                    _chip('💰 ออมได้รวม ฿$totalSaved', Colors.amber.shade50, Colors.amber.shade700),
                  if (lastResult != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      (lastResult['success'] as bool) ? '✅ เดือนที่แล้วสำเร็จ' : '❌ เดือนที่แล้วเกินเป้า',
                      style: TextStyle(fontSize: 11,
                          color: (lastResult['success'] as bool)
                              ? Colors.green.shade600 : Colors.orange.shade600),
                    ),
                  ],
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared Auto Card Shell ────────────────────────────────────────────────
class _AutoCardShell extends StatelessWidget {
  final Color color;
  final Widget icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Widget child;

  const _AutoCardShell({
    required this.color,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge,
                        style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                child,
              ],
            )),
          ],
        ),
      ),
    );
  }
}

Widget _chip(String label, Color bg, Color text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
  child: Text(label, style: TextStyle(fontSize: 10, color: text, fontWeight: FontWeight.w600)),
);