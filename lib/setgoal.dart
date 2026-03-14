import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'goalprogess.dart';
import 'createquest.dart';
import 'auth_helper.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

enum DurationType { day, month, date }

class SetGoalScreen extends StatefulWidget {
  const SetGoalScreen({super.key});

  @override
  State<SetGoalScreen> createState() => _SetGoalScreenState();
}

class _SetGoalScreenState extends State<SetGoalScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  DurationType _durationType = DurationType.day;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  int _totalDays = 0;
  double _savePerDay = 0;

  String _selectedIcon = 'assets/images/goal1.png';
  bool _enableQuest = false;

  void _recalculate() {
    final amount = double.tryParse(_amountCtrl.text);
    final durationValue = int.tryParse(_durationCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _savePerDay = 0);
      return;
    }
    DateTime end;
    switch (_durationType) {
      case DurationType.day:
        if (durationValue == null || durationValue <= 0) return;
        end = _startDate.add(Duration(days: durationValue));
        break;
      case DurationType.month:
        if (durationValue == null || durationValue <= 0) return;
        end = DateTime(_startDate.year, _startDate.month + durationValue, _startDate.day);
        break;
      case DurationType.date:
        if (_endDate == null) return;
        end = _endDate!;
        break;
    }
    final days = end.difference(_startDate).inDays;
    if (days <= 0) return;
    setState(() {
      _endDate = end;
      _totalDays = days;
      _savePerDay = amount / days;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _recalculate();
    }
  }

  Future<void> _saveGoal() async {
    if (_titleCtrl.text.isEmpty || _savePerDay <= 0) return;
    final docRef = await FirebaseFirestore.instance.collection('goals').add({
      'userID': AuthHelper.uid,
      'title': _titleCtrl.text,
      'targetAmount': double.parse(_amountCtrl.text),
      'savedAmount': 0,
      'startDate': Timestamp.fromDate(_startDate),
      'endDate': Timestamp.fromDate(_endDate!),
      'totalDays': _totalDays,
      'savePerDay': _savePerDay,
      'icon': _selectedIcon,
      'questEnabled': _enableQuest,
      'createdAt': Timestamp.now(),
    });
    if (_enableQuest) await QuestService.activateQuestForGoal(docRef.id);
    _titleCtrl.clear();
    _amountCtrl.clear();
    _durationCtrl.clear();
    setState(() {
      _savePerDay = 0;
      _totalDays = 0;
      _endDate = null;
      _enableQuest = false;
    });
  }

  String _getGoalImage(String baseIcon, double percent) {
    final match = RegExp(r'goal(\d+)\.png').firstMatch(baseIcon);
    if (match == null) return baseIcon;
    final goalNumber = match.group(1);
    if (percent >= 1.0) return 'assets/images/goal$goalNumber-5.png';
    if (percent >= 0.75) return 'assets/images/goal$goalNumber-4.png';
    if (percent >= 0.5) return 'assets/images/goal$goalNumber-3.png';
    if (percent >= 0.25) return 'assets/images/goal$goalNumber-2.png';
    return baseIcon;
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
          'เป้าหมายการออม',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── เป้าหมายที่ตั้งแล้ว ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('goals')
                  .where('userID', isEqualTo: AuthHelper.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: kPrimary));
                }
                final docs = snapshot.data!.docs;
                final sortedDocs = [...docs]..sort((a, b) {
                  final aHasQuest = (a.data() as Map<String, dynamic>)['questEnabled'] == true;
                  final bHasQuest = (b.data() as Map<String, dynamic>)['questEnabled'] == true;
                  if (aHasQuest && !bHasQuest) return -1;
                  if (!aHasQuest && bHasQuest) return 1;
                  return 0;
                });

                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.savings_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('ยังไม่มีเป้าหมาย', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final hasQuest = data['questEnabled'] == true;
                      final saved = (data['savedAmount'] as num).toDouble();
                      final target = (data['targetAmount'] as num).toDouble();
                      final percent = (saved / target).clamp(0.0, 1.0);

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GoalProgessScreen(goalId: doc.id)),
                        ),
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            // border เป็นสีทองถ้ามีภารกิจ
                            border: Border.all(
                              color: hasQuest ? Colors.amber.shade300 : Colors.grey.shade200,
                              width: hasQuest ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: hasQuest
                                    ? Colors.amber.withOpacity(0.18)
                                    : Colors.black.withOpacity(0.04),
                                blurRadius: hasQuest ? 14 : 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => GoalProgessScreen(goalId: doc.id)),
                                ),
                                splashColor: kPrimary.withOpacity(0.08),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [

                                    // ── Quest banner ด้านบนสุดของการ์ด ──
                                    if (hasQuest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        color: Colors.amber.shade400,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.emoji_events, color: Colors.white, size: 12),
                                            SizedBox(width: 5),
                                            Text(
                                              '🔥 ภารกิจเปิดอยู่',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // ── เนื้อหาการ์ด ──
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['title'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: kText,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Expanded(
                                              child: Center(
                                                child: Image.asset(
                                                  _getGoalImage(data['icon'], percent),
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: percent,
                                                minHeight: 6,
                                                backgroundColor: Colors.grey.shade100,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  percent >= 1.0 ? Colors.amber : kPrimary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '${(percent * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: percent >= 1.0 ? Colors.amber.shade700 : kPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── ฟอร์มตั้งเป้าหมายใหม่ ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.add_circle_outline, color: kPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('ตั้งเป้าหมายใหม่',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _label('รูปเป้าหมาย'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        final path = 'assets/images/goal${index + 1}.png';
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _iconChoice(path),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  _label('ชื่อเป้าหมาย'),
                  TextField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration(hint: 'เช่น ซื้อโทรศัพท์ใหม่'),
                  ),

                  const SizedBox(height: 14),

                  _label('จำนวนเงินเป้าหมาย'),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                    decoration: _inputDecoration(hint: '0', prefix: '฿  '),
                  ),

                  const SizedBox(height: 14),

                  _label('ระยะเวลา'),
                  Row(
                    children: [
                      _durationChip('วัน', DurationType.day),
                      const SizedBox(width: 8),
                      _durationChip('เดือน', DurationType.month),
                      const SizedBox(width: 8),
                      _durationChip('เลือกวัน', DurationType.date),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (_durationType != DurationType.date)
                    TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalculate(),
                      decoration: _inputDecoration(
                        hint: _durationType == DurationType.day ? 'จำนวนวัน' : 'จำนวนเดือน',
                      ),
                    ),

                  if (_durationType == DurationType.date)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryDark,
                        side: BorderSide(color: kPrimary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _endDate == null
                            ? 'เลือกวันที่สิ้นสุด'
                            : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                      ),
                    ),

                  if (_savePerDay > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimary.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: kPrimary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ออมวันละ ${_savePerDay.toStringAsFixed(2)} บาท',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Toggle Quest
                  Container(
                    decoration: BoxDecoration(
                      color: _enableQuest ? kPrimaryLight : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _enableQuest ? kPrimary.withOpacity(0.3) : Colors.grey.shade200,
                      ),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      title: const Text(
                        'สร้างภารกิจการออม',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kText),
                      ),
                      subtitle: Text(
                        _enableQuest
                            ? 'ระบบจะวิเคราะห์รายจ่ายและสร้างภารกิจให้อัตโนมัติ'
                            : 'เปิดเพื่อให้ระบบช่วยสร้างภารกิจลดรายจ่าย',
                        style: TextStyle(
                          fontSize: 11,
                          color: _enableQuest ? kPrimaryDark : Colors.grey,
                        ),
                      ),
                      secondary: Icon(
                        Icons.emoji_events,
                        color: _enableQuest ? Colors.amber : Colors.grey,
                      ),
                      value: _enableQuest,
                      activeColor: kPrimary,
                      onChanged: (v) => setState(() => _enableQuest = v),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _saveGoal,
                      child: const Text(
                        'บันทึกเป้าหมาย',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kText)),
  );

  InputDecoration _inputDecoration({String? hint, String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: kBackground,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
  );

  Widget _durationChip(String label, DurationType type) {
    final selected = _durationType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _durationType = type);
        _recalculate();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _iconChoice(String path) {
    final selected = _selectedIcon == path;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = path),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? kPrimaryLight : Colors.grey.shade50,
          border: Border.all(
            color: selected ? kPrimary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Image.asset(path, width: 56, height: 56),
      ),
    );
  }
}