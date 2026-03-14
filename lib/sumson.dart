import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'result.dart';
import 'graph.dart';
import 'inselect.dart';
import 'cateselect.dart';
import 'package:intl/intl.dart';
import 'auth_helper.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

enum RepeatType { income, expense }

class SumsonScreen extends StatefulWidget {
  const SumsonScreen({super.key});

  @override
  State<SumsonScreen> createState() => _SumsonScreenState();
}

class _SumsonScreenState extends State<SumsonScreen> {
  List<Map<String, dynamic>> _wallets = [];
  String? _selectedWalletId;
  String _categoryName = 'อื่นๆ';
  String _categoryIcon = 'assets/images/other.png';

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final moneyFormat = NumberFormat('#,##0', 'th_TH');
  final List<Map<String, dynamic>> _allRepeatList = [];

  RepeatType _type = RepeatType.expense;
  String _frequency = 'รายเดือน';

  bool _loading = true;
  bool _filterOnlySelectedWallet = false;
  RepeatType? _filterType;
  String? _filterFrequency;
  bool? _filterActive;

  @override
  void initState() {
    super.initState();
    _loadWallets().then((_) => _loadAllRepeats());
  }

  Future<void> _loadWallets() async {
    final snap = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userID', isEqualTo: AuthHelper.uid)
        .get();
    setState(() {
      _wallets = snap.docs.map((d) => {'id': d.id, 'name': d['name']}).toList();
      if (_wallets.isNotEmpty) _selectedWalletId ??= _wallets.first['id'];
    });
  }

  Future<void> _loadAllRepeats() async {
    _allRepeatList.clear();
    for (final w in _wallets) {
      final snap = await FirebaseFirestore.instance
          .collection('repeat_transactions')
          .doc(w['id'])
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();
      for (final d in snap.docs) {
        _allRepeatList.add({
          'id': d.id,
          'walletId': w['id'],
          'walletName': w['name'],
          'name': d['name'],
          'amount': d['amount'],
          'type': d['type'] == 'income' ? RepeatType.income : RepeatType.expense,
          'frequency': d['frequency'],
          'category': d.data().containsKey('category') ? d['category'] : 'อื่นๆ',
          'categoryIcon': d.data().containsKey('categoryIcon') ? d['categoryIcon'] : 'assets/images/other.png',
          'active': d.data().containsKey('active') ? d['active'] : true,
          'createdAt': d['createdAt'],
          'lastGeneratedAt': d.data().containsKey('lastGeneratedAt') ? d['lastGeneratedAt'] : null,
        });
      }
    }
    setState(() => _loading = false);
  }

  DateTime _nextDate(DateTime from, String frequency) {
    switch (frequency) {
      case 'รายวัน': return from.add(const Duration(days: 1));
      case 'รายสัปดาห์': return from.add(const Duration(days: 7));
      case 'รายปี': return DateTime(from.year + 1, from.month, from.day);
      default: return DateTime(from.year, from.month + 1, from.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _allRepeatList.where((item) {
      if (_filterOnlySelectedWallet && _selectedWalletId != null && item['walletId'] != _selectedWalletId) return false;
      if (_filterType != null && item['type'] != _filterType) return false;
      if (_filterFrequency != null && item['frequency'] != _filterFrequency) return false;
      if (_filterActive != null && item['active'] != _filterActive) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: kText,
        title: const Text(
          'รายการรายรับ-รายจ่ายซ้ำ',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (i) {
          if (i == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
          else if (i == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GraphScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ภาพรวม'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'สถิติ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_open), label: 'เมนู'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── ฟอร์มเพิ่มรายการ ──
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

                      // header
                      Row(children: const [
                        Icon(Icons.add_circle_outline, color: kPrimary, size: 20),
                        SizedBox(width: 8),
                        Text('เพิ่มรายการซ้ำ',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
                      ]),

                      const SizedBox(height: 20),

                      // toggle รายจ่าย/รายรับ
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: kBackground, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() { _type = RepeatType.expense; _resetCategory(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == RepeatType.expense ? Colors.red : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _type == RepeatType.expense
                                    ? [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 6)] : [],
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.arrow_upward,
                                    color: _type == RepeatType.expense ? Colors.white : Colors.grey.shade400, size: 16),
                                const SizedBox(width: 6),
                                Text('รายจ่าย', style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold,
                                    color: _type == RepeatType.expense ? Colors.white : Colors.grey.shade400)),
                              ]),
                            ),
                          )),
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() { _type = RepeatType.income; _resetCategory(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == RepeatType.income ? Colors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _type == RepeatType.income
                                    ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 6)] : [],
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.arrow_downward,
                                    color: _type == RepeatType.income ? Colors.white : Colors.grey.shade400, size: 16),
                                const SizedBox(width: 6),
                                Text('รายรับ', style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold,
                                    color: _type == RepeatType.income ? Colors.white : Colors.grey.shade400)),
                              ]),
                            ),
                          )),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // กระเป๋าเงิน
                      _label('กระเป๋าเงิน'),
                      DropdownButtonFormField<String>(
                        value: _selectedWalletId,
                        decoration: _inputDecoration(),
                        items: _wallets.map<DropdownMenuItem<String>>((w) =>
                            DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String))).toList(),
                        onChanged: (v) => setState(() => _selectedWalletId = v),
                      ),

                      const SizedBox(height: 16),

                      // ชื่อรายการ
                      _labelRequired('ชื่อรายการ'),
                      TextField(
                        controller: _nameController,
                        decoration: _inputDecoration(hint: 'เช่น ค่าเน็ต'),
                      ),

                      const SizedBox(height: 16),

                      // จำนวนเงิน
                      _labelRequired('จำนวนเงิน'),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: '0', prefix: '฿  '),
                      ),

                      const SizedBox(height: 16),

                      // หมวดหมู่
                      _label('หมวดหมู่ (ไม่บังคับ)'),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _type == RepeatType.income ? InSelectScreen() : CateSelectScreen(),
                          ));
                          if (result != null) setState(() {
                            _categoryName = result['name'];
                            _categoryIcon = result['icon'];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(children: [
                            Image.asset(_categoryIcon, width: 26, height: 26),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_categoryName,
                                style: const TextStyle(fontSize: 15, color: kText))),
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ความถี่
                      _label('ความถี่'),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => Container(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
                                  ...['รายวัน', 'รายสัปดาห์', 'รายเดือน', 'รายปี'].map((f) => ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    leading: const Icon(Icons.repeat, color: kPrimary),
                                    title: Text(f, style: const TextStyle(fontWeight: FontWeight.w500, color: kText)),
                                    trailing: _frequency == f ? const Icon(Icons.check, color: kPrimary) : null,
                                    onTap: () => Navigator.pop(context, f),
                                  )),
                                ],
                              ),
                            ),
                          );
                          if (result != null) setState(() => _frequency = result);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(children: [
                            const Icon(Icons.repeat, color: kPrimary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_frequency,
                                style: const TextStyle(fontSize: 15, color: kText))),
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 24),

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
                          onPressed: _addRepeatItem,
                          child: const Text('บันทึก',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── header รายการที่ตั้งไว้ ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รายการที่ตั้งไว้',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
                    InkWell(
                      onTap: _openFilterSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kPrimary.withOpacity(0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.tune, color: kPrimaryDark, size: 16),
                          SizedBox(width: 4),
                          Text('ตัวกรอง', style: TextStyle(fontSize: 12, color: kPrimaryDark, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (displayList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(children: [
                        Icon(Icons.repeat_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('ยังไม่มีรายการ',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                      ]),
                    ),
                  )
                else
                  ...displayList.map((item) {
                    final isIncome = item['type'] == RepeatType.income;
                    final baseDate = item['lastGeneratedAt'] != null
                        ? (item['lastGeneratedAt'] as Timestamp).toDate()
                        : (item['createdAt'] as Timestamp).toDate();
                    final nextDate = _nextDate(baseDate, item['frequency']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [

                            // icon วงกลม
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIncome ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'],
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
                                  const SizedBox(height: 2),
                                  Text('กระเป๋า: ${item['walletName']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${moneyFormat.format(item['amount'])} บาท',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isIncome ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, runSpacing: 4, children: [
                                    _chip(item['frequency'], kPrimaryLight, kPrimaryDark),
                                    _chip(item['category'] ?? 'อื่นๆ', kPrimaryLight, kPrimaryDark),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Icon(Icons.schedule, size: 12, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ครั้งถัดไป: ${nextDate.day}/${nextDate.month}/${nextDate.year}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ]),
                                ],
                              ),
                            ),

                            // toggle + delete
                            Column(children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.repeat, size: 22,
                                    color: item['active'] ? kPrimary : Colors.grey.shade300),
                                Switch(
                                  value: item['active'],
                                  activeColor: kPrimary,
                                  onChanged: (v) async {
                                    final docRef = FirebaseFirestore.instance
                                        .collection('repeat_transactions')
                                        .doc(item['walletId'])
                                        .collection('items')
                                        .doc(item['id']);
                                    if (v) {
                                      await docRef.update({'active': true, 'lastGeneratedAt': Timestamp.fromDate(DateTime.now())});
                                    } else {
                                      await docRef.update({'active': false});
                                    }
                                    _loadAllRepeats();
                                  },
                                ),
                              ]),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _confirmDeleteRepeat(item),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _chip(String label, Color bgColor, Color textColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kText)),
  );

  Widget _labelRequired(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kText)),
      const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    ])),
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

  Future<void> _addRepeatItem() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();
    if (_selectedWalletId == null) return;
    if (name.isEmpty || amountText.isEmpty) { _showError('กรุณากรอกชื่อรายการและจำนวนเงิน'); return; }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) { _showError('จำนวนเงินต้องมากกว่า 0'); return; }
    await FirebaseFirestore.instance.collection('repeat_transactions').doc(_selectedWalletId).collection('items').add({
      'userID': AuthHelper.uid,
      'name': name,
      'amount': amount,
      'type': _type == RepeatType.income ? 'income' : 'expense',
      'repeat': _convertFrequencyToRepeat(_frequency),
      'frequency': _frequency,
      'category': _categoryName,
      'categoryIcon': _categoryIcon,
      'walletId': _selectedWalletId,
      'active': true,
      'createdAt': Timestamp.now(),
      'lastGeneratedAt': null,
    });
    _nameController.clear();
    _amountController.clear();
    _loadAllRepeats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)))),
              const Text('ตัวกรองรายการ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เฉพาะกระเป๋าที่เลือก',
                    style: TextStyle(fontSize: 14, color: kText, fontWeight: FontWeight.w500)),
                activeColor: kPrimary,
                value: _filterOnlySelectedWallet,
                onChanged: (v) { setModal(() => _filterOnlySelectedWallet = v); setState(() {}); },
              ),
              _filterLabel('ประเภทรายการ'),
              Wrap(spacing: 8, children: [
                _filterChip('ทั้งหมด', _filterType == null, setModal, () { _filterType = null; setState(() {}); }),
                _filterChip('รายรับ', _filterType == RepeatType.income, setModal, () { _filterType = RepeatType.income; setState(() {}); }),
                _filterChip('รายจ่าย', _filterType == RepeatType.expense, setModal, () { _filterType = RepeatType.expense; setState(() {}); }),
              ]),
              const SizedBox(height: 12),
              _filterLabel('ความถี่'),
              Wrap(spacing: 8, children: ['รายวัน', 'รายสัปดาห์', 'รายเดือน', 'รายปี'].map((f) =>
                _filterChip(f, _filterFrequency == f, setModal, () {
                  _filterFrequency = _filterFrequency == f ? null : f;
                  setState(() {});
                })).toList()),
              const SizedBox(height: 12),
              _filterLabel('สถานะ'),
              Wrap(spacing: 8, children: [
                _filterChip('ทั้งหมด', _filterActive == null, setModal, () { _filterActive = null; setState(() {}); }),
                _filterChip('เปิด', _filterActive == true, setModal, () { _filterActive = true; setState(() {}); }),
                _filterChip('ปิด', _filterActive == false, setModal, () { _filterActive = false; setState(() {}); }),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
  );

  Widget _filterChip(String label, bool selected, StateSetter setModal, VoidCallback onTap) =>
    GestureDetector(
      onTap: () => setModal(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );

  void _resetCategory() {
    _categoryName = 'อื่นๆ';
    _categoryIcon = 'assets/images/other.png';
  }

  Future<void> _confirmDeleteRepeat(Map<String, dynamic> item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 42),
          const SizedBox(height: 12),
          const Text('ลบรายการซ้ำ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
          const SizedBox(height: 8),
          Text('คุณต้องการลบรายการ "${item['name']}" ใช่หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('repeat_transactions')
                    .doc(item['walletId'])
                    .collection('items')
                    .doc(item['id'])
                    .delete();
                Navigator.pop(context);
                _loadAllRepeats();
              },
              child: const Text('ลบ'),
            )),
          ]),
        ]),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _convertFrequencyToRepeat(String frequency) {
    switch (frequency) {
      case 'รายวัน': return 'daily';
      case 'รายสัปดาห์': return 'weekly';
      case 'รายเดือน': return 'monthly';
      case 'รายปี': return 'yearly';
      default: return 'monthly';
    }
  }
}