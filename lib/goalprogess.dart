import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'createquest.dart';
import 'showquest.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class GoalProgessScreen extends StatefulWidget {
  final String goalId;

  const GoalProgessScreen({super.key, required this.goalId});

  @override
  State<GoalProgessScreen> createState() => _GoalProgressScreenState();
}

class _GoalProgressScreenState extends State<GoalProgessScreen>
    with SingleTickerProviderStateMixin {
  final _addMoneyCtrl = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _progressAnim;
  double _lastPercent = 0;
  bool _questLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  void _animateTo(double percent) {
    if ((percent - _lastPercent).abs() < 0.001) return;
    _progressAnim = Tween<double>(begin: _lastPercent, end: percent).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _lastPercent = percent;
    _animController.forward(from: 0);
  }

  @override
  void dispose() {
    _animController.dispose();
    _addMoneyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSaving(DocumentReference ref, double currentSaved) async {
    final add = double.tryParse(_addMoneyCtrl.text);
    if (add == null || add <= 0) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(ref, {'savedAmount': currentSaved + add});
    batch.set(ref.collection('savingLogs').doc(), {
      'amount': add,
      'source': 'manual',
      'createdAt': Timestamp.now(),
    });
    await batch.commit();
    _addMoneyCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _deleteGoal(DocumentReference ref) async {
    await ref.delete();
    Navigator.pop(context);
  }

  Future<void> _activateQuests(String goalTitle) async {
    setState(() => _questLoading = true);
    try {
      await QuestService.activateQuestForGoal(widget.goalId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ สร้างภารกิจสำเร็จ!'),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
      ));

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuestScreen(goalId: widget.goalId, goalTitle: goalTitle),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _questLoading = false);
    }
  }

  String _getGoalImage(String baseIcon, double percent) {
    final match = RegExp(r'goal(\d+)\.png').firstMatch(baseIcon);
    if (match == null) return baseIcon;
    final n = match.group(1);
    if (percent >= 1.0) return 'assets/images/goal$n-5.png';
    if (percent >= 0.75) return 'assets/images/goal$n-4.png';
    if (percent >= 0.5) return 'assets/images/goal$n-3.png';
    if (percent >= 0.25) return 'assets/images/goal$n-2.png';
    return baseIcon;
  }

  String _fmt(double n) => n.toInt().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},',
  );

  String _sourceLabel(String? source) {
    switch (source) {
      case 'daily_quest': return 'ภารกิจรายวัน';
      case 'limit_quest': return 'ภารกิจลดรายจ่าย';
      case 'habit_quest': return 'ภารกิจนิสัยดี';
      case 'self_compare_quest': return 'ภารกิจเทียบตัวเอง';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(widget.goalId);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: kText,
        title: const Text(
          'ความคืบหน้า',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: goalRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] as String;
          final icon = data['icon'] as String;
          final target = (data['targetAmount'] as num).toDouble();
          final saved = (data['savedAmount'] as num).toDouble();
          final start = (data['startDate'] as Timestamp).toDate();
          final end = (data['endDate'] as Timestamp).toDate();
          final savePerDay = data.containsKey('savePerDay')
              ? (data['savePerDay'] as num).toDouble()
              : 0.0;
          final questEnabled = data['questEnabled'] as bool? ?? false;
          final percent = (saved / target).clamp(0.0, 1.0);
          final daysLeft = end.difference(DateTime.now()).inDays;

          WidgetsBinding.instance.addPostFrameCallback((_) => _animateTo(percent));

          return StreamBuilder<QuerySnapshot>(
            stream: goalRef
                .collection('savingLogs')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              final logs = snap.hasData ? snap.data!.docs : <QueryDocumentSnapshot>[];

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12, offset: const Offset(0, 4),
                              )],
                            ),
                            child: Column(
                              children: [
                                Image.asset(_getGoalImage(icon, percent), width: 120, height: 120),
                                const SizedBox(height: 8),
                                Text(title,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kText),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${DateFormat('dd/MM/yy').format(start)} – ${DateFormat('dd/MM/yy').format(end)}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: daysLeft > 0 ? kPrimaryLight : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        daysLeft > 0 ? 'เหลือ $daysLeft วัน' : 'หมดแล้ว',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                            color: daysLeft > 0 ? kPrimaryDark : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.trending_up, size: 13, color: kPrimary),
                                    const SizedBox(width: 4),
                                    Text('ออมวันละ ฿${_fmt(savePerDay)}',
                                        style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w600)),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                AnimatedBuilder(
                                  animation: _progressAnim,
                                  builder: (context, _) => Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: _progressAnim.value,
                                          minHeight: 12,
                                          backgroundColor: Colors.grey.shade100,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              percent >= 1.0 ? Colors.amber : kPrimary),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('฿${_fmt(saved)}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimary)),
                                          Text('${(percent * 100).toStringAsFixed(1)}%',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kText)),
                                          Text('฿${_fmt(target)}',
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _milestone('25%', 0.25, percent),
                                    _connector(percent >= 0.25),
                                    _milestone('50%', 0.50, percent),
                                    _connector(percent >= 0.50),
                                    _milestone('75%', 0.75, percent),
                                    _connector(percent >= 0.75),
                                    _milestone('100%', 1.0, percent),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          _QuestButton(
                            questEnabled: questEnabled,
                            loading: _questLoading,
                            onActivate: () => _activateQuests(title),
                            onOpen: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => QuestScreen(goalId: widget.goalId, goalTitle: title),
                            )),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200, width: 1.5),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8, offset: const Offset(0, 2),
                              )],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _addMoneyCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'เพิ่มเงินออม',
                                      prefixText: '฿  ',
                                      isDense: true,
                                      filled: true,
                                      fillColor: kBackground,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: kPrimary, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _addSaving(goalRef, saved),
                                  child: const Text('เพิ่ม', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200, width: 1.5),
                                left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                                right: BorderSide(color: Colors.grey.shade200, width: 1.5),
                              ),
                            ),
                            child: const Text('ประวัติการออม',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kText)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (logs.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 1.5),
                              left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                              right: BorderSide(color: Colors.grey.shade200, width: 1.5),
                            ),
                          ),
                          child: Center(
                            child: Text('ยังไม่มีประวัติการออม',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final log = logs[index].data() as Map<String, dynamic>;
                            final amount = (log['amount'] as num).toDouble();
                            final date = (log['createdAt'] as Timestamp).toDate();
                            final source = log['source'] as String?;
                            final isQuest = source != null && source.contains('quest');
                            final label = _sourceLabel(source);
                            final isLast = index == logs.length - 1;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: isLast
                                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                                    : BorderRadius.zero,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isLast ? Colors.grey.shade200 : Colors.grey.shade100,
                                    width: isLast ? 1.5 : 1,
                                  ),
                                  left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                                  right: BorderSide(color: Colors.grey.shade200, width: 1.5),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: isQuest ? Colors.amber.shade50 : kPrimaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isQuest ? Icons.emoji_events : Icons.savings_outlined,
                                    size: 16,
                                    color: isQuest ? Colors.amber : kPrimary,
                                  ),
                                ),
                                title: Text('+฿${_fmt(amount)}',
                                    style: TextStyle(fontWeight: FontWeight.bold,
                                        color: isQuest ? Colors.amber.shade700 : kPrimary, fontSize: 14)),
                                subtitle: isQuest
                                    ? Row(children: [
                                        const Icon(Icons.emoji_events, size: 11, color: Colors.amber),
                                        const SizedBox(width: 3),
                                        Text(label, style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                                      ])
                                    : null,
                                trailing: Text(
                                  DateFormat('dd/MM/yy HH:mm').format(date),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                ),
                              ),
                            );
                          },
                          childCount: logs.length,
                        ),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final confirm = await _showDeleteSheet();
                          if (confirm) _deleteGoal(goalRef);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: const Text('ลบเป้าหมาย', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _milestone(String label, double threshold, double percent) {
    final reached = percent >= threshold;
    return Column(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: reached ? kPrimary : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: reached ? kPrimary : Colors.grey.shade300, width: 1.5),
          ),
          child: Icon(reached ? Icons.check : Icons.lock_outline,
              size: 14, color: reached ? Colors.white : Colors.grey.shade400),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
            color: reached ? kPrimary : Colors.grey.shade400)),
      ],
    );
  }

  Widget _connector(bool reached) => Expanded(
    child: Container(
      height: 2, margin: const EdgeInsets.only(bottom: 18),
      color: reached ? kPrimary : Colors.grey.shade200,
    ),
  );

  Future<bool> _showDeleteSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            const Text('ลบเป้าหมาย',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
            const SizedBox(height: 8),
            Text('คุณต้องการลบเป้าหมายนี้ใช่หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ลบ'),
                )),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}

class _QuestButton extends StatelessWidget {
  final bool questEnabled;
  final bool loading;
  final VoidCallback onActivate;
  final VoidCallback onOpen;

  const _QuestButton({
    required this.questEnabled,
    required this.loading,
    required this.onActivate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!questEnabled) {

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: loading ? null : onActivate,
          icon: loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.emoji_events_outlined, size: 20),
          label: Text(loading ? 'กำลังสร้างภารกิจ...' : '🎯 เปิดใช้งานภารกิจ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryLight,
          foregroundColor: kPrimaryDark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onOpen,
        icon: const Icon(Icons.emoji_events, size: 20),
        label: const Text('ดูภารกิจ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}