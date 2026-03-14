import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_helper.dart';
import 'cateselect.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('จัดการกิจกรรม',
            style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        foregroundColor: kText,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('userID', isEqualTo: AuthHelper.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                  child: const Icon(Icons.celebration_rounded, size: 48, color: kPrimary),
                ),
                const SizedBox(height: 16),
                const Text('ยังไม่มีกิจกรรม',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
                const SizedBox(height: 6),
                Text('กดปุ่ม + เพื่อเพิ่มกิจกรรมแรก',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ]),
            );
          }

          final active = docs.where((d) => (d.data() as Map)['status'] != 'done').toList();
          final done = docs.where((d) => (d.data() as Map)['status'] == 'done').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _sectionLabel('กำลังดำเนินการ'),
                const SizedBox(height: 8),
                ...active.map((d) => _EventCard(doc: d)),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('เสร็จสิ้นแล้ว'),
                const SizedBox(height: 8),
                ...done.map((d) => _EventCard(doc: d, dimmed: true)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const _AddEventScreen())),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryDark)),
);

class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool dimmed;
  const _EventCard({required this.doc, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final totalBudget = (data['totalBudget'] as num? ?? 0).toDouble();
    final totalSpent = (data['totalSpent'] as num? ?? 0).toDouble();
    final date = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
    final isDone = data['status'] == 'done';
    final iconPath = data['iconPath'] as String?;
    final progress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > totalBudget && totalBudget > 0;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => _EventDetailScreen(eventId: doc.id))),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(10)),
                child: Image.asset(iconPath ?? 'assets/images/event.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
                if (description.isNotEmpty)
                  Text(description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text('เสร็จแล้ว',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ),
              if (date != null && !isDone)
                Text('${date.day}/${date.month}/${date.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
            if (totalBudget > 0) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('ใช้ไป ฿${_fmt(totalSpent)}',
                    style: TextStyle(fontSize: 12, color: isOver ? Colors.red : Colors.grey.shade600)),
                Text('งบ ฿${_fmt(totalBudget)}',
                    style: const TextStyle(fontSize: 12, color: kText, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(isOver ? Colors.red : kPrimary),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toInt().toString();
}

class _AddEventScreen extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? initial;
  const _AddEventScreen({this.eventId, this.initial});

  @override
  State<_AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<_AddEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime? _eventDate;
  String? _iconPath;
  bool _isLoading = false;

  bool get _isEdit => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final d = widget.initial!;
      _titleCtrl.text = d['title'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _budgetCtrl.text = d['totalBudget']?.toString() ?? '';
      _iconPath = d['iconPath'] as String?;
      if (d['date'] != null) _eventDate = (d['date'] as Timestamp).toDate();
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('กรุณาใส่ชื่อกิจกรรม');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final payload = {
        'userID': AuthHelper.uid,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'totalBudget': double.tryParse(_budgetCtrl.text) ?? 0,
        'date': _eventDate != null ? Timestamp.fromDate(_eventDate!) : null,
        'status': 'active',
        'iconPath': _iconPath,
      };
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('events').doc(widget.eventId)
            .update({...payload, 'updatedAt': Timestamp.now()});
      } else {
        await FirebaseFirestore.instance.collection('events').add({
          ...payload,
          'totalSpent': 0.0,
          'createdAt': Timestamp.now(),
        });
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'แก้ไขกิจกรรม' : 'เพิ่มกิจกรรม',
            style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        foregroundColor: kText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(builder: (_) => CateSelectScreen()),
                );
                if (result != null) setState(() => _iconPath = result['icon']);
              },
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _iconPath != null ? kPrimary : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: _iconPath != null
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(_iconPath!, fit: BoxFit.contain))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: kPrimary, size: 28),
                        const SizedBox(height: 4),
                        Text('เลือกไอคอน',
                            style: TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
                      ]),
              ),
            ),
          ),
          if (_iconPath != null)
            Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, String>>(
                    context,
                    MaterialPageRoute(builder: (_) => CateSelectScreen()),
                  );
                  if (result != null) setState(() => _iconPath = result['icon']);
                },
                child: const Text('เปลี่ยนไอคอน',
                    style: TextStyle(fontSize: 12, color: kPrimary)),
              ),
            ),
          const SizedBox(height: 20),
          _label('ชื่อกิจกรรม *'),
          _field(_titleCtrl, hint: 'เช่น งานแต่งงาน, เที่ยวญี่ปุ่น'),
          const SizedBox(height: 14),
          _label('รายละเอียด'),
          _field(_descCtrl, hint: 'หมายเหตุ...', maxLines: 2),
          const SizedBox(height: 14),
          _label('งบประมาณรวม'),
          _field(_budgetCtrl, hint: '0', keyboardType: TextInputType.number, prefix: '฿  '),
          const SizedBox(height: 14),
          _label('วันจัดงาน'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _eventDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _eventDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  _eventDate != null
                      ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}'
                      : 'เลือกวันที่',
                  style: TextStyle(
                      fontSize: 14,
                      color: _eventDate != null ? kText : Colors.grey.shade400),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isEdit ? 'บันทึก' : 'สร้างกิจกรรม',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

Widget _label(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
);

Widget _field(TextEditingController ctrl,
    {String hint = '', int maxLines = 1, TextInputType? keyboardType, String? prefix, ValueChanged<String>? onChanged}) =>
  TextField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(
      filled: true, fillColor: Colors.white, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintText: hint,
      prefixText: prefix,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    ),
  );

class _EventDetailScreen extends StatelessWidget {
  final String eventId;
  const _EventDetailScreen({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
      builder: (context, snapEvent) {
        if (!snapEvent.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary)));
        }
        final data = snapEvent.data!.data() as Map<String, dynamic>? ?? {};
        final title = data['title'] as String? ?? '';
        final totalBudget = (data['totalBudget'] as num? ?? 0).toDouble();
        final totalSpent = (data['totalSpent'] as num? ?? 0).toDouble();
        final isDone = data['status'] == 'done';
        final isOver = totalSpent > totalBudget && totalBudget > 0;
        final progress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
        final iconPath = data['iconPath'] as String?;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 28, height: 28,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(8)),
                child: Image.asset(iconPath ?? 'assets/images/event.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title,
                    style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            centerTitle: true,
            foregroundColor: kText,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: kText),
                onSelected: (v) async {
                  if (v == 'edit') {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _AddEventScreen(eventId: eventId, initial: data)));
                  } else if (v == 'toggle') {
                    await FirebaseFirestore.instance.collection('events').doc(eventId)
                        .update({'status': isDone ? 'active' : 'done'});
                  } else if (v == 'delete') {
                    final confirm = await _confirmDelete(context, title);
                    if (confirm) {
                      final items = await FirebaseFirestore.instance
                          .collection('events').doc(eventId)
                          .collection('items').get();
                      for (var item in items.docs) {
                        final txId = (item.data())['transactionId'] as String?;
                        if (txId != null) {
                          await FirebaseFirestore.instance
                              .collection('transactions').doc(txId)
                              .delete().catchError((_) {});
                        }
                        await item.reference.delete();
                      }
                      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('แก้ไขกิจกรรม')),
                  PopupMenuItem(value: 'toggle',
                      child: Text(isDone ? 'เปิดใช้งานอีกครั้ง' : 'ทำเครื่องหมายเสร็จสิ้น')),
                  const PopupMenuItem(value: 'delete',
                      child: Text('ลบกิจกรรม', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          body: Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(children: [
                Row(children: [
                  _summaryChip('งบรวม', '฿${_fmt(totalBudget)}', kPrimaryDark),
                  const SizedBox(width: 8),
                  _summaryChip('ใช้ไป', '฿${_fmt(totalSpent)}',
                      isOver ? Colors.red : kPrimary),
                  const SizedBox(width: 8),
                  _summaryChip('คงเหลือ', '฿${_fmt((totalBudget - totalSpent).abs())}',
                      isOver ? Colors.red.shade300 : Colors.grey.shade600),
                ]),
                if (totalBudget > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(isOver ? Colors.red : kPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${(progress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11,
                            color: isOver ? Colors.red : Colors.grey.shade500)),
                  ]),
                ],
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events').doc(eventId)
                    .collection('items')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapItems) {
                  final items = snapItems.data?.docs ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.playlist_add_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('ยังไม่มีรายการ กดปุ่ม + วางแผนรายการ',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      ]),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) =>
                        _ItemCard(eventId: eventId, doc: items[i]),
                  );
                },
              ),
            ),
          ]),
          floatingActionButton: FloatingActionButton(
            backgroundColor: kPrimary,
            onPressed: () => _showPlanItemSheet(context, eventId, totalBudget: totalBudget),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _summaryChip(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: kBackground, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  final String eventId;
  final QueryDocumentSnapshot doc;
  const _ItemCard({required this.eventId, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '';
    final budget = (data['budgetAmount'] as num? ?? 0).toDouble();
    final spent = (data['spentAmount'] as num? ?? 0).toDouble();
    final isPaid = data['status'] == 'paid';
    final note = data['note'] as String? ?? '';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirmDelete(context, name),
      onDismissed: (_) async {
        final txId = data['transactionId'] as String?;
        if (txId != null) {
          await FirebaseFirestore.instance
              .collection('transactions').doc(txId)
              .delete().catchError((_) {});
        }
        await FirebaseFirestore.instance.collection('events').doc(eventId)
            .update({'totalSpent': FieldValue.increment(-spent)});
        await doc.reference.delete();
      },
      child: GestureDetector(
        onTap: () => _showPayItemSheet(context, eventId, doc.id, data),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPaid ? kPrimary.withOpacity(0.3) : Colors.grey.shade100),
          ),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isPaid ? kPrimary : Colors.transparent,
                border: Border.all(color: isPaid ? kPrimary : Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isPaid ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: kText,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  )),
              if (note.isNotEmpty)
                Text(note, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (spent > 0)
                Text('฿${_fmt(spent)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: isPaid ? kPrimary : kText)),
              if (budget > 0 && spent == 0)
                Text('ตั้งงบ ฿${_fmt(budget)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
              if (budget > 0 && spent > 0)
                Text('งบ ฿${_fmt(budget)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (!isPaid)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('กดเพื่อจ่าย', style: TextStyle(fontSize: 10, color: kPrimary)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── _showPlanItemSheet ────────────────────────────────────────────────────────
// เพิ่ม totalBudget และ currentItemBudget เพื่อคำนวณงบคงเหลือ
void _showPlanItemSheet(BuildContext context, String eventId, {
  String? itemId,
  Map<String, dynamic>? initial,
  double totalBudget = 0,
}) {
  final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
  final budgetCtrl = TextEditingController(
      text: initial != null && (initial['budgetAmount'] ?? 0) > 0
          ? (initial['budgetAmount'] as num).toInt().toString() : '');
  final noteCtrl = TextEditingController(text: initial?['note'] ?? '');

  // งบของ item นี้ก่อนแก้ไข (ใช้หักออกเวลาคำนวณงบคงเหลือตอนแก้ไข)
  final double originalItemBudget = initial != null
      ? (initial['budgetAmount'] as num? ?? 0).toDouble()
      : 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        // ดึงยอดรวม budgetAmount ของ items ทั้งหมด (real-time จาก Firestore)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(eventId)
              .collection('items')
              .snapshots(),
          builder: (ctx, snapItems) {
            // รวม budgetAmount ของ items ทั้งหมด ยกเว้น item ที่กำลังแก้ไขอยู่
            double plannedBudget = 0;
            for (final doc in snapItems.data?.docs ?? []) {
              if (doc.id == itemId) continue; // ข้าม item ที่กำลังแก้ไข
              plannedBudget += ((doc.data() as Map)['budgetAmount'] as num? ?? 0).toDouble();
            }

            // งบที่พิมพ์อยู่ตอนนี้
            final typedBudget = double.tryParse(budgetCtrl.text) ?? 0;
            // งบคงเหลือ = งบรวม - วางแผนไว้แล้ว - ที่กำลังพิมพ์
            final remaining = totalBudget - plannedBudget - typedBudget;
            final isOver = totalBudget > 0 && remaining < 0;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(itemId == null ? 'วางแผนรายการ' : 'แก้ไขแผนรายการ',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kText)),
                  const SizedBox(height: 4),
                  Text('ตั้งงบล่วงหน้า — ลงจ่ายจริงได้ทีหลัง',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const SizedBox(height: 16),
                  _label('ชื่อรายการ *'),
                  _field(nameCtrl, hint: 'เช่น ชุดแต่งงาน, ค่าเช่าสถานที่'),
                  const SizedBox(height: 12),
                  _label('งบตั้งต้น'),
                  _field(budgetCtrl,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    prefix: '฿ ',
                    onChanged: (_) => setModal(() {}), // อัปเดต remaining ทุกครั้งที่พิมพ์
                  ),

                  // ── แสดงงบคงเหลือ (เฉพาะเมื่อ event มีการตั้งงบรวม) ──
                  if (totalBudget > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOver ? Colors.red.shade50 : kPrimaryLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOver ? Colors.red.shade200 : kPrimary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(
                              isOver ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                              size: 14,
                              color: isOver ? Colors.red : kPrimaryDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOver ? 'งบเกิน!' : 'งบตั้งต้นคงเหลือ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOver ? Colors.red : kPrimaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                          Text(
                            '฿${_fmt(remaining.abs())}${isOver ? ' (เกิน)' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOver ? Colors.red : kPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  _label('โน้ต'),
                  _field(noteCtrl, hint: 'หมายเหตุ...'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final budget = double.tryParse(budgetCtrl.text) ?? 0;
                        final payload = {
                          'name': nameCtrl.text.trim(),
                          'budgetAmount': budget,
                          'note': noteCtrl.text.trim(),
                        };
                        if (itemId != null) {
                          await FirebaseFirestore.instance
                              .collection('events').doc(eventId)
                              .collection('items').doc(itemId)
                              .update(payload);
                        } else {
                          await FirebaseFirestore.instance
                              .collection('events').doc(eventId)
                              .collection('items')
                              .add({
                            ...payload,
                            'spentAmount': 0.0,
                            'status': 'pending',
                            'createdAt': Timestamp.now(),
                          });
                        }
                      },
                      child: Text(itemId == null ? 'เพิ่มรายการ' : 'บันทึก',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    ),
  );
}

// _field เวอร์ชันรับ onChanged เพิ่มเติม
Widget _fieldWithChange(TextEditingController ctrl, {
  String hint = '',
  int maxLines = 1,
  TextInputType? keyboardType,
  String? prefix,
  ValueChanged<String>? onChanged,
}) =>
  TextField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(
      filled: true, fillColor: Colors.white, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintText: hint,
      prefixText: prefix,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    ),
  );

void _showPayItemSheet(BuildContext context, String eventId,
    String itemId, Map<String, dynamic> data) {
  final name = data['name'] as String? ?? '';
  final budget = (data['budgetAmount'] as num? ?? 0).toDouble();
  final oldSpent = (data['spentAmount'] as num? ?? 0).toDouble();
  final isPaid = data['status'] == 'paid';

  final spentCtrl = TextEditingController(
      text: oldSpent > 0 ? oldSpent.toInt().toString() : '');
  final noteCtrl = TextEditingController(text: data['note'] as String? ?? '');

  List<QueryDocumentSnapshot> wallets = [];
  String? selectedWalletId = data['walletId'] as String?;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        if (wallets.isEmpty) {
          FirebaseFirestore.instance
              .collection('wallets')
              .where('userID', isEqualTo: AuthHelper.uid)
              .get()
              .then((snap) {
            setModal(() {
              wallets = snap.docs;
              selectedWalletId ??= wallets.isNotEmpty ? wallets.first.id : null;
            });
          });
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ลงยอดจ่าย',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kText)),
                  Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ])),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(8)),
                    child: const Text('จ่ายแล้ว',
                        style: TextStyle(fontSize: 12, color: kPrimaryDark, fontWeight: FontWeight.w600)),
                  ),
              ]),
              if (budget > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: kBackground, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text('งบตั้งต้น ฿${_fmt(budget)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              _label('ยอดจ่ายจริง'),
              _field(spentCtrl, hint: '0', keyboardType: TextInputType.number, prefix: '฿ '),
              const SizedBox(height: 12),
              if (wallets.isNotEmpty) ...[
                _label('หักจากกระเป๋า'),
                DropdownButtonFormField<String>(
                  value: selectedWalletId,
                  isDense: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimary)),
                  ),
                  items: wallets.map((w) {
                    final d = w.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: w.id, child: Text(d['name'] ?? ''));
                  }).toList(),
                  onChanged: (v) => setModal(() => selectedWalletId = v),
                ),
                const SizedBox(height: 12),
              ],
              _label('โน้ต'),
              _field(noteCtrl, hint: 'หมายเหตุ...'),
              const SizedBox(height: 16),
              Row(children: [
                if (isPaid) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final txId = data['transactionId'] as String?;
                        if (txId != null) {
                          await FirebaseFirestore.instance
                              .collection('transactions').doc(txId)
                              .delete().catchError((_) {});
                        }
                        await FirebaseFirestore.instance
                            .collection('events').doc(eventId)
                            .collection('items').doc(itemId)
                            .update({
                          'spentAmount': 0.0,
                          'status': 'pending',
                          'transactionId': FieldValue.delete(),
                        });
                        await FirebaseFirestore.instance
                            .collection('events').doc(eventId)
                            .update({'totalSpent': FieldValue.increment(-oldSpent)});
                      },
                      child: const Text('ยกเลิกการจ่าย',
                          style: TextStyle(color: Colors.red, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final spent = double.tryParse(spentCtrl.text) ?? 0;
                      if (spent <= 0) return;
                      Navigator.pop(ctx);

                      final spentDiff = spent - oldSpent;
                      String? txId = data['transactionId'] as String?;

                      if (selectedWalletId != null) {
                        if (txId != null) {
                          await FirebaseFirestore.instance
                              .collection('transactions').doc(txId)
                              .update({'amount': spent.toInt()});
                        } else {
                          final ref = await FirebaseFirestore.instance
                              .collection('transactions').add({
                            'userID': AuthHelper.uid,
                            'walletId': selectedWalletId,
                            'type': 'expense',
                            'amount': spent.toInt(),
                            'category': 'กิจกรรม',
                            'categoryIcon': 'assets/images/other.png',
                            'note': name,
                            'date': Timestamp.now(),
                            'createdAt': Timestamp.now(),
                            'fromEvent': true,
                            'eventId': eventId,
                          });
                          txId = ref.id;
                        }
                      }

                      await FirebaseFirestore.instance
                          .collection('events').doc(eventId)
                          .collection('items').doc(itemId)
                          .update({
                        'spentAmount': spent,
                        'note': noteCtrl.text.trim(),
                        'status': 'paid',
                        'walletId': selectedWalletId,
                        if (txId != null) 'transactionId': txId,
                      });

                      await FirebaseFirestore.instance
                          .collection('events').doc(eventId)
                          .update({'totalSpent': FieldValue.increment(spentDiff)});
                    },
                    child: const Text('บันทึกยอดจ่าย',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPlanItemSheet(context, eventId, itemId: itemId, initial: data);
                  },
                  child: Text('แก้ไขชื่อ / งบตั้งต้น',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ),
              ),
            ]),
          ),
        );
      },
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ยืนยันการลบ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text('ต้องการลบ "$name" ใช่หรือไม่?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600))),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  return result ?? false;
}