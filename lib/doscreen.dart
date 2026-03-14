import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cateselect.dart';
import 'inselect.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'auth_helper.dart';
import 'createquest.dart';


const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class DoScreen extends StatefulWidget {
  final String? initialWalletId;

  const DoScreen({super.key, this.initialWalletId});

  @override
  State<DoScreen> createState() => _DoScreenState();
}

class _DoScreenState extends State<DoScreen> {
  String type = 'expense';

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String? selectedCategoryName;
  String? selectedCategoryIcon;

  DateTime selectedDate = DateTime.now();

  String? selectedWalletId;
  List<QueryDocumentSnapshot> wallets = [];

  List<String> _pendingSlipPaths = [];

  List<Map<String, String>> _frequentExpense = [];
  List<Map<String, String>> _frequentIncome = [];

  Future<void> _loadFrequentCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('userID', isEqualTo: AuthHelper.uid)
        .orderBy('date', descending: true)
        .limit(100)
        .get();

    final Map<String, Map<String, dynamic>> expCount = {};
    final Map<String, Map<String, dynamic>> incCount = {};

    for (final doc in snap.docs) {
      final d = doc.data();
      final t = d['type'] as String? ?? '';
      final name = d['category'] as String? ?? '';
      final icon = d['categoryIcon'] as String? ?? '';
      if (name.isEmpty) continue;
      final target = t == 'expense' ? expCount : incCount;
      if (!target.containsKey(name)) target[name] = {'icon': icon, 'count': 0};
      target[name]!['count'] = (target[name]!['count'] as int) + 1;
    }

    List<Map<String, String>> top(Map<String, Map<String, dynamic>> m) {
      final sorted = m.entries.toList()
        ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
      return sorted.take(4).map((e) => {'name': e.key, 'icon': e.value['icon'] as String}).toList();
    }

    setState(() {
      _frequentExpense = top(expCount);
      _frequentIncome = top(incCount);
    });
  }

  Future<void> _loadWallets() async {
    final snapshot = await FirebaseFirestore.instance.collection('wallets')
        .where('userID', isEqualTo: AuthHelper.uid).get();
    setState(() {
      wallets = snapshot.docs;
      if (widget.initialWalletId != null &&
          wallets.any((d) => d.id == widget.initialWalletId)) {
        selectedWalletId ??= widget.initialWalletId;
      } else if (wallets.isNotEmpty) {
        selectedWalletId ??= wallets.first.id;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadWallets();
    _loadFrequentCategories();
  }

  Future<void> _selectCategory() async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => type == 'expense' ? CateSelectScreen() : InSelectScreen(),
    ));
    if (result != null && result is Map) {
      setState(() {
        selectedCategoryName = result['name'];
        selectedCategoryIcon = result['icon'];
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _saveTransaction() async {
    if (amountController.text.isEmpty || selectedCategoryName == null || selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกข้อมูลให้ครบ'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('transactions').add({
      'userID': AuthHelper.uid,
      'type': type,
      'amount': (double.parse(amountController.text)).round(),
      'category': selectedCategoryName,
      'categoryIcon': selectedCategoryIcon,
      'note': noteController.text,
      'walletId': selectedWalletId,
      'date': Timestamp.fromDate(selectedDate),
      'slipPaths': _pendingSlipPaths,
    });

    // ── แจ้ง habit quest ว่าวันนี้มีการบันทึกแล้ว ──
    try {
      final activeGoalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .where('userID', isEqualTo: AuthHelper.uid)
          .where('questEnabled', isEqualTo: true)
          .limit(1)
          .get();
      if (activeGoalSnap.docs.isNotEmpty) {
        final goalId = activeGoalSnap.docs.first.id;
        await QuestService.checkHabitQuests(goalId);
      }
    } catch (_) {}

    if (type == 'expense') {
      await _checkBudgetAfterSave();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _checkBudgetAfterSave() async {
    final budgetDoc = await FirebaseFirestore.instance.collection('budgets').doc(selectedWalletId).get();
    if (!budgetDoc.exists) { if (mounted) Navigator.pop(context); return; }

    final budgetData = budgetDoc.data()!;
    final budgetAmount = (budgetData['amount'] as num).toInt();
    final mode = budgetData['mode'] as String? ?? 'none';

    final txSnap = await FirebaseFirestore.instance.collection('transactions')
        .where('walletId', isEqualTo: selectedWalletId)
        .where('type', isEqualTo: 'expense').get();

    int totalExpense = 0;
    if (mode == 'customDate' && budgetData['startDate'] != null && budgetData['endDate'] != null) {
      final start = (budgetData['startDate'] as Timestamp).toDate();
      final end = (budgetData['endDate'] as Timestamp).toDate();
      for (var doc in txSnap.docs) {
        final d = (doc['date'] as Timestamp).toDate();
        if (!d.isBefore(start) && !d.isAfter(end)) totalExpense += (doc['amount'] as num).toInt();
      }
    } else {
      totalExpense = txSnap.docs.fold<int>(0, (sum, doc) => sum + (doc['amount'] as num).toInt());
    }

    final remaining = budgetAmount - totalExpense;

    // ── แก้ orElse type error ──
    

    if (remaining < 0 && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.red.shade50,
          title: Column(children: [
            Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.warning_rounded, color: Colors.red, size: 40)),
            const SizedBox(height: 12),
            const Text('⚠️ ใช้เกินงบประมาณ!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('รายการนี้ทำให้คุณใช้เกินงบไป',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text('฿ ${remaining.abs()}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red))),
            const SizedBox(height: 12),
            Text('บันทึกรายการสำเร็จแล้ว\nกรุณาตรวจสอบงบประมาณของคุณ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ]),
          actions: [SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context),
            child: const Text('รับทราบ'),
          ))],
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _scanSlip() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimary)));

    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final List<Map<String, dynamic>> results = [];

      for (final file in pickedFiles) {
        final inputImage = InputImage.fromFilePath(file.path);
        final recognized = await recognizer.processImage(inputImage);
        final lines = recognized.text.split('\n');
        double bestAmount = 0;
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.contains('X') || trimmed.contains('x')) continue;
          if (trimmed.length > 20) continue;
          final match = RegExp(r'([\d,]+\.\d{2})').firstMatch(trimmed);
          if (match != null) {
            final val = double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
            if (val > 0) bestAmount = val;
          }
        }
        results.add({'path': file.path, 'amount': bestAmount.toInt()});
      }

      await recognizer.close();
      Navigator.pop(context);
      _showMultiScanResultDialog(results);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อ่านสลิปไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  void _showMultiScanResultDialog(List<Map<String, dynamic>> results) {
    final controllers = results.map((r) =>
        TextEditingController(text: r['amount'] > 0 ? r['amount'].toString() : '')).toList();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              Text('พบ ${results.length} สลิป',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
              const SizedBox(height: 4),
              Text('กดรูปเพื่อดูเต็ม · แก้ไขยอดได้ก่อนบันทึก',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kBackground, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => showDialog(context: context,
                            builder: (_) => Dialog(backgroundColor: Colors.transparent,
                                child: InteractiveViewer(child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(File(results[i]['path'])))))),
                        child: Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(results[i]['path']), width: 64, height: 64, fit: BoxFit.cover)),
                          Positioned(bottom: 2, right: 2, child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                          )),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('สลิปที่ ${i + 1}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controllers[i], keyboardType: TextInputType.number,
                          onChanged: (_) => setModal(() {}),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: kPrimary)),
                            prefixText: '฿ ', hintText: 'ไม่พบยอด กรอกเอง',
                            isDense: true, filled: true, fillColor: Colors.white,
                          ),
                        ),
                      ])),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withOpacity(0.2))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('ยอดรวมทั้งหมด',
                      style: TextStyle(fontWeight: FontWeight.w600, color: kText)),
                  Text('฿${controllers.fold<int>(0, (s, c) => s + (int.tryParse(c.text) ?? 0))}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryDark)),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  showDialog(context: context, barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimary)));
                  final List<String> savedPaths = [];
                  final piclocate = await getApplicationDocumentsDirectory();
                  final slipsDir = Directory('${piclocate.path}/slips');
                  if (!await slipsDir.exists()) await slipsDir.create(recursive: true);
                  for (int i = 0; i < results.length; i++) {
                    try {
                      final file = File(results[i]['path']);
                      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                      final saved = await file.copy('${slipsDir.path}/$fileName');
                      savedPaths.add(saved.path);
                    } catch (e) { savedPaths.add(''); }
                  }
                  final total = controllers.fold<int>(0, (s, c) => s + (int.tryParse(c.text) ?? 0));
                  Navigator.pop(context);
                  Navigator.pop(context);
                  setState(() {
                    amountController.text = total.toString();
                    _pendingSlipPaths = savedPaths;
                    selectedCategoryName ??= 'อื่นๆ';
                    selectedCategoryIcon ??= 'assets/images/other.png';
                  });
                },
                child: const Text('ใช้ยอดรวมและบันทึกสลิป',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = type == 'expense';

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('บันทึกรายการ',
            style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        foregroundColor: kText,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Toggle รายรับ/รายจ่าย ──
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { type = 'expense'; selectedCategoryName = null; selectedCategoryIcon = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isExpense ? Colors.red.shade500 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isExpense ? [BoxShadow(color: Colors.red.withOpacity(0.25), blurRadius: 6, offset: const Offset(0,2))] : [],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.arrow_upward_rounded, color: isExpense ? Colors.white : Colors.grey.shade400, size: 15),
                    const SizedBox(width: 5),
                    Text('รายจ่าย', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: isExpense ? Colors.white : Colors.grey.shade400)),
                  ]),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() { type = 'income'; selectedCategoryName = null; selectedCategoryIcon = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: !isExpense ? Colors.green.shade500 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: !isExpense ? [BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 6, offset: const Offset(0,2))] : [],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.arrow_downward_rounded, color: !isExpense ? Colors.white : Colors.grey.shade400, size: 15),
                    const SizedBox(width: 5),
                    Text('รายรับ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: !isExpense ? Colors.white : Colors.grey.shade400)),
                  ]),
                ),
              )),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Scan Slip Banner Card ──
          GestureDetector(
            onTap: _scanSlip,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimary, kPrimaryDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Image.asset('assets/images/scanslip.png', width: 36, height: 36),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('สแกนสลิป',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('อ่านยอดอัตโนมัติ ไม่ต้องพิมพ์เอง',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.85))),
                ])),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // ── กระเป๋าเงิน ──
          _label('กระเป๋าเงิน'),
          DropdownButtonFormField<String>(
            value: selectedWalletId,
            decoration: _inputDecoration(),
            isDense: true,
            items: wallets.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem(value: doc.id, child: Text(data['name']));
            }).toList(),
            onChanged: (v) => setState(() => selectedWalletId = v),
          ),

          const SizedBox(height: 14),

          // ── หมวดหมู่ ──
          _label('หมวดหมู่'),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                selectedCategoryIcon == null || selectedCategoryIcon!.isEmpty
                    ? Icon(Icons.category_outlined, color: Colors.grey.shade400, size: 22)
                    : Image.asset(selectedCategoryIcon!, width: 24, height: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(selectedCategoryName ?? 'เลือกหมวดหมู่',
                    style: TextStyle(fontSize: 14,
                        color: selectedCategoryName == null ? Colors.grey.shade400 : kText))),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
              ]),
            ),
          ),

          // ── Quick chips หมวดที่ใช้บ่อย ──
          Builder(builder: (context) {
            final freq = type == 'expense' ? _frequentExpense : _frequentIncome;
            if (freq.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.history_rounded, size: 13, color: kPrimary),
                  const SizedBox(width: 4),
                  const Text('หมวดหมู่ที่ใช้บ่อย',
                      style: TextStyle(fontSize: 12, color: kPrimaryDark, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 7),
                _buildCategorySection(),
              ]),
            );
          }),

          const SizedBox(height: 14),

          // ── จำนวนเงิน ──
          _label('จำนวนเงิน'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isExpense ? Colors.red.shade200 : Colors.green.shade200, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red.shade600 : Colors.green.shade600),
              decoration: InputDecoration(
                border: InputBorder.none, isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixText: '฿  ',
                prefixStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.grey.shade300),
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Slip thumbnails
          if (_pendingSlipPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.image_outlined, size: 13, color: kPrimary),
              const SizedBox(width: 4),
              Text('แนบสลิป ${_pendingSlipPaths.length} รูป', style: const TextStyle(fontSize: 11, color: kPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _pendingSlipPaths = []),
                child: Text('ลบ', style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
              ),
            ]),
            const SizedBox(height: 6),
            SizedBox(height: 52, child: ListView.builder(
              scrollDirection: Axis.horizontal, itemCount: _pendingSlipPaths.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog(context: context,
                    builder: (_) => Dialog(backgroundColor: Colors.transparent,
                        child: InteractiveViewer(child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_pendingSlipPaths[i])))))),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_pendingSlipPaths[i]), width: 52, height: 52, fit: BoxFit.cover)),
                ),
              ),
            )),
          ],

          const SizedBox(height: 14),

          // ── โน้ต + วันที่ ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('โน้ต (ไม่บังคับ)'),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  filled: true, fillColor: Colors.white, isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                  hintText: 'หมายเหตุ...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('วันที่'),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_month_rounded, color: kPrimary, size: 16),
                    const SizedBox(width: 6),
                    Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 13, color: kText, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ]),
          ]),

          const SizedBox(height: 24),

          // ── ปุ่มบันทึก ──
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _saveTransaction,
            child: const Text('บันทึก',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  Widget _buildCategorySection() {
    final freq = type == 'expense' ? _frequentExpense : _frequentIncome;
    if (freq.isEmpty) {
      return GestureDetector(
        onTap: _selectCategory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            selectedCategoryIcon == null || selectedCategoryIcon!.isEmpty
                ? Icon(Icons.category_outlined, color: Colors.grey.shade400, size: 22)
                : Image.asset(selectedCategoryIcon!, width: 24, height: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(selectedCategoryName ?? 'เลือกหมวดหมู่',
                style: TextStyle(fontSize: 14,
                    color: selectedCategoryName == null ? Colors.grey.shade400 : kText))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ]),
        ),
      );
    }

    final chips = <Widget>[];
    for (final cat in freq) {
      final isSelected = selectedCategoryName == cat['name'];
      chips.add(GestureDetector(
        onTap: () => setState(() {
          selectedCategoryName = cat['name'];
          selectedCategoryIcon = (cat['icon'] != null && cat['icon']!.isNotEmpty) ? cat['icon'] : null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? kPrimary : Colors.grey.shade200, width: isSelected ? 0 : 1),
            boxShadow: [BoxShadow(
              color: isSelected ? kPrimary.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (cat['icon'] != null && cat['icon']!.isNotEmpty) ...[
              Image.asset(cat['icon']!, width: 20, height: 20),
              const SizedBox(width: 7),
            ],
            Text(cat['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : kText)),
          ]),
        ),
      ));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kText)),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary)),
  );
}