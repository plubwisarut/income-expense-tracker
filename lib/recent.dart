import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'doscreen.dart';
import 'graph.dart';
import 'goal.dart';
import 'result.dart';
import 'auth_helper.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class RecentScreen extends StatefulWidget {
  final DateTime? initialDate; // ถ้าส่งมาจากปฏิทิน จะกรองเฉพาะวันนั้น
  const RecentScreen({super.key, this.initialDate});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  bool _sortNewestFirst = true;
  bool _isLoadingWallets = true;

  String? _selectedWalletId;
  String? _selectedCategory;
  DateTime? _filterDate;

  List<Wallet> wallets = [];

  static const List<String> expenseCategories = [
    'อาหาร', 'ขนม/ของหวาน', 'น้ำหวาน/กาแฟ', 'เดินทาง', 'ที่พัก',
    'ช้อปปิ้ง', 'บันเทิง', 'เติมเกม', 'ค่าโทรศัพท์', 'เสื้อผ้า',
    'เครื่องสำอาง', 'สกินแคร์', 'ค่าเทอม', 'สังสรรค์', 'การแพทย์',
    'สัตว์เลี้ยง', 'อื่นๆ',
  ];

  static const List<String> incomeCategories = [
    'ค่าขนม', 'เงินเดือน', 'งานเสริม', 'โบนัส', 'ของขวัญ', 'อื่นๆ',
  ];

  final Map<String, String> categoryImages = {
    'อาหาร': 'assets/images/food.png',
    'ขนม/ของหวาน': 'assets/images/kanomwan.png',
    'น้ำหวาน/กาแฟ': 'assets/images/numwann.png',
    'เดินทาง': 'assets/images/travel.png',
    'ที่พัก': 'assets/images/home.png',
    'ช้อปปิ้ง': 'assets/images/shop.png',
    'บันเทิง': 'assets/images/game.png',
    'เติมเกม': 'assets/images/termgame.png',
    'ค่าโทรศัพท์': 'assets/images/phone.png',
    'เสื้อผ้า': 'assets/images/cloth.png',
    'เครื่องสำอาง': 'assets/images/sumang.png',
    'สกินแคร์': 'assets/images/skincare.png',
    'ค่าเทอม': 'assets/images/educate.png',
    'สังสรรค์': 'assets/images/funny.png',
    'การแพทย์': 'assets/images/medic.png',
    'สัตว์เลี้ยง': 'assets/images/animals.png',
    'อื่นๆ': 'assets/images/other.png',
  };

  final Map<String, String> incomeCategoryImages = {
    'ค่าขนม': 'assets/images/kanom.png',
    'เงินเดือน': 'assets/images/salary.png',
    'งานเสริม': 'assets/images/extra.png',
    'โบนัส': 'assets/images/bonus.png',
    'ของขวัญ': 'assets/images/gift.png',
    'อื่นๆ': 'assets/images/other.png',
  };

  @override
  void initState() {
    super.initState();
    _filterDate = widget.initialDate;
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final lastWalletId = prefs.getString('last_wallet_id');
    final snapshot = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userID', isEqualTo: AuthHelper.uid)
        .get();
    final loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return Wallet(
        id: doc.id,
        name: data['name'],
        iconPath: data['iconPath'],
        initialBalance: (data['initialBalance'] as num? ?? 0).toInt(),
      );
    }).toList();
    setState(() {
      wallets = loaded;
      _isLoadingWallets = false;
      // ถ้ามาจากปฏิทินให้แสดงทุกกระเป๋า ไม่ set _selectedWalletId
      if (_filterDate == null) {
        if (lastWalletId != null && loaded.any((w) => w.id == lastWalletId)) {
          _selectedWalletId = lastWalletId;
        } else if (loaded.isNotEmpty) {
          _selectedWalletId = loaded.first.id;
        }
      }
    });
  }

  String _getWalletName(String walletId) {
    try {
      return wallets.firstWhere((w) => w.id == walletId).name;
    } catch (_) {
      return 'ไม่ทราบกระเป๋า';
    }
  }

  String _getImagePath(String category, String type) {
    if (type == 'income') return incomeCategoryImages[category] ?? 'assets/images/other.png';
    return categoryImages[category] ?? 'assets/images/other.png';
  }

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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 42),
          const SizedBox(height: 12),
          const Text('ลบรายการ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('คุณต้องการลบรายการนี้ใช่หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), child: const Text('ลบ'),
            )),
          ]),
        ]),
      ),
    );
    return result ?? false;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)))),
              const Text('ตัวกรองรายการ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
              const SizedBox(height: 20),
              const Text('กระเป๋าเงิน',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _filterChip(label: 'ทุกกระเป๋า', selected: _selectedWalletId == null,
                  onTap: () { setModal(() => _selectedWalletId = null); setState(() => _selectedWalletId = null); }),
                ...wallets.map((w) => _filterChip(
                  label: w.name, selected: _selectedWalletId == w.id,
                  onTap: () { setModal(() => _selectedWalletId = w.id); setState(() => _selectedWalletId = w.id); })),
              ]),
              const SizedBox(height: 20),
              const Text('หมวดหมู่',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _filterChip(label: 'ทุกหมวด', selected: _selectedCategory == null,
                      onTap: () { setModal(() => _selectedCategory = null); setState(() => _selectedCategory = null); }),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(width: 3, height: 14,
                          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text('รายจ่าย', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ...expenseCategories.map((cat) => _filterChip(
                        label: cat, selected: _selectedCategory == cat,
                        activeColor: Colors.red.shade400,
                        onTap: () { setModal(() => _selectedCategory = cat); setState(() => _selectedCategory = cat); })),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Container(width: 3, height: 14,
                          decoration: BoxDecoration(color: Colors.green.shade500, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text('รายรับ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade500)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ...incomeCategories.map((cat) => _filterChip(
                        label: cat, selected: _selectedCategory == cat,
                        activeColor: Colors.green.shade500,
                        onTap: () { setModal(() => _selectedCategory = cat); setState(() => _selectedCategory = cat); })),
                    ]),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              const Text('เรียงลำดับ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
              const SizedBox(height: 10),
              Row(children: [
                _filterChip(label: 'ล่าสุดก่อน', selected: _sortNewestFirst,
                  onTap: () { setModal(() => _sortNewestFirst = true); setState(() {}); }),
                const SizedBox(width: 10),
                _filterChip(label: 'เก่าสุดก่อน', selected: !_sortNewestFirst,
                  onTap: () { setModal(() => _sortNewestFirst = false); setState(() {}); }),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap, Color? activeColor}) {
    final color = activeColor ?? kPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : kBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : Colors.grey.shade600,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _appBarBadge({required String label, required Color color, required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 5, 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(width: 3),
        GestureDetector(onTap: onRemove,
          child: Icon(Icons.close_rounded, size: 13, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool fromCalendar = widget.initialDate != null;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: fromCalendar
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kText),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(children: [
          Text(
            fromCalendar
                ? 'ธุรกรรม ${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}'
                : 'ธุรกรรม',
            style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (!fromCalendar && (_selectedWalletId != null || _selectedCategory != null)) ...[
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (_selectedWalletId != null) _appBarBadge(
                label: wallets.firstWhere((w) => w.id == _selectedWalletId,
                    orElse: () => Wallet(id: '', name: 'กระเป๋า', iconPath: '', initialBalance: 0)).name,
                color: kPrimary,
                onRemove: () => setState(() => _selectedWalletId = null)),
              if (_selectedWalletId != null && _selectedCategory != null) const SizedBox(width: 6),
              if (_selectedCategory != null) _appBarBadge(
                label: _selectedCategory!,
                color: expenseCategories.contains(_selectedCategory)
                    ? Colors.red.shade400 : Colors.green.shade500,
                onRemove: () => setState(() => _selectedCategory = null)),
            ]),
          ],
        ]),
        centerTitle: true,
        actions: [
          if (!fromCalendar)
            IconButton(
              icon: const Icon(Icons.tune, color: kPrimaryDark),
              tooltip: 'ตัวกรอง',
              onPressed: _openFilterSheet,
            ),
        ],
      ),
      bottomNavigationBar: fromCalendar ? null : BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
          else if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => DoScreen(initialWalletId: _selectedWalletId)));
          else if (index == 3) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GraphScreen()));
          else if (index == 4) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ภาพรวม'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'ธุรกรรม'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 46, color: kPrimary), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'สถิติ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_open), label: 'เมนู'),
        ],
      ),
      body: _isLoadingWallets
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : wallets.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('ยังไม่มีกระเป๋าเงิน', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  Text('กลับไปสร้างกระเป๋าเงินที่หน้าหลักก่อนนะครับ',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ]))
              : Column(children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: () {
                        Query query = FirebaseFirestore.instance
                            .collection('transactions')
                            .where('userID', isEqualTo: AuthHelper.uid);
                        if (_selectedWalletId != null) query = query.where('walletId', isEqualTo: _selectedWalletId);
                        if (_selectedCategory != null) query = query.where('category', isEqualTo: _selectedCategory);
                        // กรองเฉพาะวันที่จากปฏิทิน
                        if (_filterDate != null) {
                          final start = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day, 0, 0, 0);
                          final end = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day, 23, 59, 59);
                          query = query
                              .where('date', isGreaterThanOrEqualTo: start)
                              .where('date', isLessThanOrEqualTo: end);
                        }
                        query = query.orderBy('date', descending: _sortNewestFirst);
                        return query.snapshots();
                      }(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('ไม่พบรายการ', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                            if (_selectedCategory != null || _selectedWalletId != null) ...[
                              const SizedBox(height: 8),
                              Text('ลองเปลี่ยนตัวกรองดูครับ',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                            ],
                          ]));
                        }
                        final Map<DateTime, List<QueryDocumentSnapshot>> grouped = {};
                        for (var doc in docs) {
                          final date = (doc['date'] as Timestamp).toDate();
                          final key = DateTime(date.year, date.month, date.day);
                          grouped.putIfAbsent(key, () => []);
                          grouped[key]!.add(doc);
                        }
                        final sortedDates = grouped.keys.toList()
                          ..sort((a, b) => _sortNewestFirst ? b.compareTo(a) : a.compareTo(b));
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final docsInDay = grouped[date]!;
                            int dayIncome = 0, dayExpense = 0;
                            for (var doc in docsInDay) {
                              if (doc['type'] == 'income') dayIncome += doc['amount'] as int;
                              else dayExpense += doc['amount'] as int;
                            }
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [
                                    Container(width: 3, height: 14,
                                        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 8),
                                    Text('${date.day}/${date.month}/${date.year}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kText)),
                                  ]),
                                  Row(children: [
                                    if (dayIncome > 0) Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text('+$dayIncome', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600))),
                                    if (dayIncome > 0 && dayExpense > 0) const SizedBox(width: 6),
                                    if (dayExpense > 0) Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                      child: Text('-$dayExpense', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600))),
                                  ]),
                                ]),
                              ),
                              ...docsInDay.map((doc) {
                                final isIncome = doc['type'] == 'income';
                                final walletName = _getWalletName(doc['walletId'] as String);
                                final hasNote = doc['note'] != null && doc['note'].toString().isNotEmpty;
                                final showWallet = _selectedWalletId == null;
                                return Dismissible(
                                  key: Key(doc.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
                                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 26)),
                                  confirmDismiss: (_) async => await _showDeleteSheet(),
                                  onDismissed: (_) async {
                                    await FirebaseFirestore.instance.collection('transactions').doc(doc.id).delete();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: const Text('ลบรายการแล้ว'),
                                        backgroundColor: kPrimaryDark,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      leading: Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: isIncome ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.07),
                                          borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.all(6),
                                        child: Image.asset(_getImagePath(doc['category'] as String, doc['type'] as String))),
                                      title: Text(doc['category'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kText)),
                                      subtitle: Text(
                                        showWallet
                                            ? walletName + (hasNote ? '  ·  ' + (doc['note'] as String) : '')
                                            : (hasNote ? doc['note'] as String : walletName),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      trailing: Text(
                                        '${isIncome ? '+' : '-'}${doc['amount']}',
                                        style: TextStyle(
                                          color: isIncome ? Colors.green.shade600 : Colors.red.shade500,
                                          fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ]);
                          },
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}