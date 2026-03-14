import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'doscreen.dart';
import 'graph.dart';
import 'models/filter_type.dart';
import 'addwallet.dart';
import 'calendar.dart';
import 'goal.dart';
import 'recent.dart';
import 'quest_banner.dart';
import 'createquest.dart';
import 'auth_helper.dart';
import 'noti.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

enum BudgetRepeat { daily, weekly, monthly }
enum BudgetMode { none, customDate, repeat }

class Wallet {
  String id;
  String name;
  String iconPath;
  int initialBalance;

  Wallet({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.initialBalance,
  });
}

class Budget {
  int amount;
  DateTime? startDate;
  DateTime? endDate;
  BudgetMode mode;
  BudgetRepeat? repeat;

  Budget({
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.mode,
    this.repeat,
  });
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _isLoadingWallets = true;
  FilterType _filterType = FilterType.day;
  bool _isDialogOpen = false;
  int _selectedSummary = 0;
  String? _activeQuestGoalId;
  List<Wallet> wallets = [];
  int selectedWalletIndex = 0;
  String? lastWalletId;
  Wallet? get currentWallet => wallets.isNotEmpty ? wallets[selectedWalletIndex] : null;

  Budget? activeBudget;
  bool _hasShownOverBudgetWarning = false;

  String _firstName = 'คุณ';

  Future<void> _loadUserName() async {
    final uid = AuthHelper.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final fullName = (doc.data()?['name'] as String? ?? '').trim();
      final firstName = fullName.split(' ').first;
      if (firstName.isNotEmpty) setState(() => _firstName = firstName);
    }
  }

  final Map<String, Color> incomeCategoryColors = {
    'ค่าขนม': Colors.amber,
    'เงินเดือน': Colors.green,
    'งานเสริม': Colors.blue,
    'โบนัส': Colors.teal,
    'ของขวัญ': Colors.pink,
    'อื่นๆ': Colors.blueGrey,
  };

  final Map<String, Color> categoryColors = {
    'อาหาร': Colors.deepOrange,
    'ขนม/ของหวาน': Colors.purpleAccent,
    'น้ำหวาน/กาแฟ': Colors.brown,
    'เดินทาง': Colors.lightBlue,
    'ที่พัก': Colors.indigo,
    'ช้อปปิ้ง': Colors.purple,
    'บันเทิง': Colors.deepPurple,
    'เติมเกม': Colors.redAccent,
    'ค่าโทรศัพท์': Colors.teal,
    'เสื้อผ้า': Colors.cyan,
    'เครื่องสำอาง': Colors.pinkAccent,
    'สกินแคร์': Colors.lime,
    'ค่าเทอม': Colors.lightGreen,
    'สังสรรค์': Colors.orange,
    'การแพทย์': Colors.red,
    'สัตว์เลี้ยง': Colors.greenAccent,
    'อื่นๆ': Colors.grey,
  };

  double _budgetProgress(List<QueryDocumentSnapshot> docs) {
    if (activeBudget == null) return 0;
    final remaining = _remainingBudget(docs);
    final total = activeBudget!.amount;
    if (total <= 0) return 0;
    return (remaining / total).clamp(0.0, 1.0);
  }

  bool _isInRange(DateTime date) {
    final now = DateTime.now();
    switch (_filterType) {
      case FilterType.day:
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case FilterType.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !date.isBefore(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)) &&
            !date.isAfter(DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59));
      case FilterType.month:
        return date.year == now.year && date.month == now.month;
    }
  }

  Future<void> _loadActiveQuestGoal() async {
    final snap = await FirebaseFirestore.instance
        .collection('goals')
        .where('userID', isEqualTo: AuthHelper.uid)
        .where('questEnabled', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final goalId = snap.docs.first.id;
      setState(() => _activeQuestGoalId = goalId);
      if (DateTime.now().day == 1) {
        await QuestService.checkMonthlyLimitQuests(goalId);
      }
    }
  }

  Future<void> _loadWallets() async {
    setState(() => _isLoadingWallets = true);
    final prefs = await SharedPreferences.getInstance();
    lastWalletId = prefs.getString('last_wallet_id');
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
    int index = 0;
    if (lastWalletId != null) {
      final foundIndex = loaded.indexWhere((w) => w.id == lastWalletId);
      if (foundIndex != -1) index = foundIndex;
    }
    setState(() {
      wallets = loaded;
      selectedWalletIndex = index;
      _isLoadingWallets = false;
    });
    if (loaded.isNotEmpty) {
      _loadBudget();
      await _checkAndGenerateRepeatTransactions();
    }
  }

  Future<void> _onWalletChanged(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_wallet_id', wallets[index].id);
    setState(() {
      selectedWalletIndex = index;
      _hasShownOverBudgetWarning = false;
    });
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    if (currentWallet == null) return;
    final doc = await FirebaseFirestore.instance.collection('budgets').doc(currentWallet!.id).get();
    if (!doc.exists) { setState(() => activeBudget = null); return; }
    final data = doc.data()!;
    final mode = BudgetMode.values.firstWhere((e) => e.name == data['mode'], orElse: () => BudgetMode.none);
    setState(() {
      activeBudget = Budget(
        amount: (data['amount'] as num).toInt(),
        mode: mode,
        startDate: data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : null,
        endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
        repeat: data['repeat'] != null
            ? BudgetRepeat.values.firstWhere((e) => e.name == data['repeat'])
            : null,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadWallets();
    _loadActiveQuestGoal();
    _loadUserName();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) setState(() => _showScrollToTop = true);
      else if (_scrollController.offset <= 100 && _showScrollToTop) setState(() => _showScrollToTop = false);
    });
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  Future<void> _addWallet() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWalletScreen()));
    _loadWallets();
  }

  Future<void> _confirmDeleteWallet() async {
    if (currentWallet == null) return;
    final confirm = await _showDeleteSheet(
      title: 'ลบกระเป๋าเงิน',
      message: 'คุณต้องการลบ "${currentWallet!.name}" ใช่หรือไม่?\nข้อมูลทั้งหมดจะถูกลบถาวร',
    );
    if (!confirm) return;
    await _deleteWallet();
  }

  Future<void> _deleteWallet() async {
    if (currentWallet == null) return;
    final walletId = currentWallet!.id;
    await FirebaseFirestore.instance.collection('wallets').doc(walletId).delete();
    await FirebaseFirestore.instance.collection('budgets').doc(walletId).delete().catchError((_) {});
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_wallet_id');
    if (lastId == walletId) await prefs.remove('last_wallet_id');
    await _loadWallets();
  }

  int _walletBalance(List<QueryDocumentSnapshot> docs) {
    if (currentWallet == null) return 0;
    int income = 0, expense = 0;
    for (var doc in docs) {
      if (doc['walletId'] == currentWallet!.id) {
        if (doc['type'] == 'income') income += doc['amount'] as int;
        else expense += doc['amount'] as int;
      }
    }
    return currentWallet!.initialBalance + income - expense;
  }

  int _remainingBudget(List<QueryDocumentSnapshot> docs) {
    if (activeBudget == null || currentWallet == null) return 0;
    int expense = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['walletId'] == currentWallet!.id && data['type'] == 'expense') {
        final cat = data['category'] as String? ?? '';
        if (activeBudget!.mode == BudgetMode.none) {
          expense += (data['amount'] as num).toInt();
        } else if (activeBudget!.startDate != null && activeBudget!.endDate != null) {
          final d = (data['date'] as Timestamp).toDate();
          if (!d.isBefore(activeBudget!.startDate!) && !d.isAfter(activeBudget!.endDate!)) {
            expense += (data['amount'] as num).toInt();
          }
        }
      }
    }
    return activeBudget!.amount - expense;
  }

  Future<void> _checkAndGenerateRepeatTransactions() async {
    if (currentWallet == null) return;
    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('repeat_transactions').doc(currentWallet!.id).collection('items')
        .where('active', isEqualTo: true).get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String type = data['type'], category = data['category'],
          walletId = data['walletId'], repeat = data['repeat'];
      final int amount = data['amount'];
      final String? note = data['note'];
      final DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
      final DateTime? lastGeneratedAt = data['lastGeneratedAt'] != null
          ? (data['lastGeneratedAt'] as Timestamp).toDate() : null;
      DateTime generateDate = lastGeneratedAt ?? createdAt.subtract(const Duration(days: 1));

      while (true) {
        final nextDate = _calculateNextDate(generateDate, repeat);
        if (nextDate.isAfter(now)) {

          try {
            await NotificationService.scheduleRepeatTransactionReminder(
              index: snapshot.docs.indexOf(doc),
              category: category,
              amount: amount,
              nextDate: nextDate,
            );
          } catch (_) {}
          break;
        }
        await FirebaseFirestore.instance.collection('transactions').add({
          'userID': AuthHelper.uid, 'type': type, 'amount': amount, 'category': category,
          'walletId': walletId, 'note': note, 'date': Timestamp.fromDate(nextDate),
          'createdAt': Timestamp.now(), 'fromRepeat': true, 'repeatId': doc.id,
        });
        generateDate = nextDate;
        await doc.reference.update({'lastGeneratedAt': Timestamp.fromDate(generateDate)});
      }
    }
  }

  DateTime _calculateNextDate(DateTime from, String repeat) {
    switch (repeat) {
      case 'daily': return from.add(const Duration(days: 1));
      case 'weekly': return from.add(const Duration(days: 7));
      case 'monthly': return DateTime(from.year, from.month + 1, from.day);
      default: return from;
    }
  }

  void _checkOverBudgetAlert(List<QueryDocumentSnapshot> docs) {
    if (activeBudget == null || currentWallet == null) return;
    final remaining = _remainingBudget(docs);
    if (remaining < 0 && !_hasShownOverBudgetWarning && !_isDialogOpen) {
      _hasShownOverBudgetWarning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showOverBudgetDialog(remaining.abs()); });
    } else if (remaining >= 0) {
      _hasShownOverBudgetWarning = false;
    }
  }

  void _showOverBudgetDialog(int overAmount) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    showDialog(
      context: context, barrierDismissible: false,
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
          Text('คุณใช้เกินงบไปแล้ว', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
              child: Text('฿ $overAmount',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red))),
          const SizedBox(height: 12),
          Text('กรุณาตรวจสอบรายจ่ายและปรับแผนการใช้เงินของคุณ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ]),
        actions: [SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => Navigator.pop(context), child: const Text('รับทราบ'),
        ))],
      ),
    ).then((_) => _isDialogOpen = false);
  }

  void _showAddBudgetDialog() {
    final amountController = TextEditingController();
    BudgetMode mode = BudgetMode.none;
    BudgetRepeat repeatType = BudgetRepeat.monthly;
    DateTime? startDate, endDate;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const Text('เพิ่มงบประมาณ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: amountController, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'จำนวนเงิน', prefixIcon: const Icon(Icons.payments, color: kPrimary),
                filled: true, fillColor: kBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary)))),
          const SizedBox(height: 20),
          const Text('รูปแบบงบประมาณ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: BudgetMode.values.map((m) {
            IconData icon; String label;
            switch (m) {
              case BudgetMode.none: icon = Icons.remove_circle_outline; label = 'ไม่ตั้ง'; break;
              case BudgetMode.customDate: icon = Icons.date_range; label = 'เลือกวัน'; break;
              case BudgetMode.repeat: icon = Icons.repeat; label = 'วนซ้ำ'; break;
            }
            final selected = mode == m;
            return Expanded(child: GestureDetector(onTap: () => setModalState(() => mode = m),
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: selected ? kPrimary : Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Icon(icon, color: selected ? Colors.white : Colors.grey.shade500),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade700, fontSize: 13)),
                ]))));
          }).toList()),
          const SizedBox(height: 16),
          if (mode == BudgetMode.customDate) Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () async { final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setModalState(() => startDate = p); },
              child: Text(startDate == null ? 'วันเริ่มต้น' : '${startDate!.day}/${startDate!.month}/${startDate!.year}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () async { final p = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: startDate ?? DateTime.now(), lastDate: DateTime(2100)); if (p != null) setModalState(() => endDate = p); },
              child: Text(endDate == null ? 'วันสิ้นสุด' : '${endDate!.day}/${endDate!.month}/${endDate!.year}'))),
          ]),
          if (mode == BudgetMode.repeat) DropdownButtonFormField<BudgetRepeat>(
            value: repeatType, decoration: const InputDecoration(labelText: 'รอบการวนซ้ำ'),
            items: const [
              DropdownMenuItem(value: BudgetRepeat.daily, child: Text('รายวัน')),
              DropdownMenuItem(value: BudgetRepeat.weekly, child: Text('รายสัปดาห์')),
              DropdownMenuItem(value: BudgetRepeat.monthly, child: Text('รายเดือน')),
            ],
            onChanged: (v) => setModalState(() => repeatType = v!)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('บันทึกงบประมาณ', style: TextStyle(fontSize: 16)),
            onPressed: () async {
              if (currentWallet == null) return;
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              await FirebaseFirestore.instance.collection('budgets').doc(currentWallet!.id).set({
                'amount': amount, 'walletId': currentWallet!.id, 'mode': mode.name,
                'startDate': mode == BudgetMode.customDate && startDate != null ? Timestamp.fromDate(startDate!) : null,
                'endDate': mode == BudgetMode.customDate && endDate != null ? Timestamp.fromDate(endDate!) : null,
                'repeat': mode == BudgetMode.repeat ? repeatType.name : null,
              });
              Navigator.pop(context);
              setState(() => _hasShownOverBudgetWarning = false);
              _loadBudget();
            })),
        ]),
      )),
    );
  }

  void _showEditBudgetDialog() {
    if (activeBudget == null || currentWallet == null) return;
    final controller = TextEditingController(text: activeBudget!.amount.toString());
    BudgetMode mode = activeBudget!.mode;
    BudgetRepeat repeatType = activeBudget!.repeat ?? BudgetRepeat.monthly;
    DateTime? startDate = mode == BudgetMode.customDate ? activeBudget!.startDate : null;
    DateTime? endDate = mode == BudgetMode.customDate ? activeBudget!.endDate : null;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)))),
            const Text('แก้ไขงบประมาณ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: controller, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: '0', prefixIcon: const Icon(Icons.attach_money, color: kPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary)))),
            const SizedBox(height: 20),
            const Text('รูปแบบงบประมาณ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: BudgetMode.values.map((m) {
              IconData icon; String label;
              switch (m) {
                case BudgetMode.none: icon = Icons.remove_circle_outline; label = 'ไม่ตั้ง'; break;
                case BudgetMode.customDate: icon = Icons.date_range; label = 'เลือกวัน'; break;
                case BudgetMode.repeat: icon = Icons.repeat; label = 'วนซ้ำ'; break;
              }
              final selected = mode == m;
              return Expanded(child: GestureDetector(onTap: () => setModalState(() => mode = m),
                child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: selected ? kPrimary : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Icon(icon, color: selected ? Colors.white : Colors.grey),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black87)),
                  ]))));
            }).toList()),
            const SizedBox(height: 16),
            if (mode == BudgetMode.customDate) Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () async { final p = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setModalState(() => startDate = p); },
                child: Text(startDate == null ? 'วันเริ่มต้น' : '${startDate!.day}/${startDate!.month}/${startDate!.year}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: () async { final p = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: startDate ?? DateTime.now(), lastDate: DateTime(2100)); if (p != null) setModalState(() => endDate = p); },
                child: Text(endDate == null ? 'วันสิ้นสุด' : '${endDate!.day}/${endDate!.month}/${endDate!.year}'))),
            ]),
            if (mode == BudgetMode.repeat) DropdownButtonFormField<BudgetRepeat>(
              value: repeatType, decoration: const InputDecoration(labelText: 'รอบการวนซ้ำ'),
              items: const [
                DropdownMenuItem(value: BudgetRepeat.daily, child: Text('รายวัน')),
                DropdownMenuItem(value: BudgetRepeat.weekly, child: Text('รายสัปดาห์')),
                DropdownMenuItem(value: BudgetRepeat.monthly, child: Text('รายเดือน')),
              ],
              onChanged: (v) => setModalState(() => repeatType = v!)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimary)),
                onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                onPressed: () async {
                  final newAmount = double.tryParse(controller.text) ?? 0;
                  await FirebaseFirestore.instance.collection('budgets').doc(currentWallet!.id).update({
                    'amount': newAmount, 'mode': mode.name,
                    'startDate': mode == BudgetMode.customDate && startDate != null ? Timestamp.fromDate(startDate!) : null,
                    'endDate': mode == BudgetMode.customDate && endDate != null ? Timestamp.fromDate(endDate!) : null,
                    'repeat': mode == BudgetMode.repeat ? repeatType.name : null,
                    'updatedAt': Timestamp.now(),
                  });
                  Navigator.pop(context);
                  setState(() => _hasShownOverBudgetWarning = false);
                  _loadBudget();
                },
                child: const Text('บันทึก'))),
            ]),
          ]),
        ),
      )),
    );
  }

  Future<void> _confirmDeleteBudget() async {
    if (currentWallet == null) return;
    final confirm = await _showDeleteSheet(title: 'ลบงบประมาณ',
        message: 'คุณต้องการลบงบประมาณของกระเป๋านี้ใช่หรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้');
    if (!confirm) return;
    await FirebaseFirestore.instance.collection('budgets').doc(currentWallet!.id).delete();
    setState(() { activeBudget = null; _hasShownOverBudgetWarning = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สวัสดี $_firstName 👋',
                style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: kPrimaryDark),
            tooltip: 'ปฏิทิน',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RecentScreen()));
          else if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => DoScreen(initialWalletId: currentWallet?.id)));
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
      floatingActionButton: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: _showScrollToTop
            ? FloatingActionButton(backgroundColor: kPrimary,
                child: const Icon(Icons.arrow_upward),
                onPressed: () => _scrollController.animateTo(0,
                    duration: const Duration(milliseconds: 500), curve: Curves.easeOut))
            : null,
      ),
      body: _isLoadingWallets
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : wallets.isEmpty
              ? _noWalletUI()
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userID', isEqualTo: AuthHelper.uid)
                      .where('walletId', isEqualTo: currentWallet!.id)
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
                    final docs = snapshot.data!.docs;
                    _checkOverBudgetAlert(docs);
                    final balance = _walletBalance(docs);

                    int incomeFiltered = 0, expenseFiltered = 0;
                    Map<String, double> incomeCategorySum = {}, expenseCategorySum = {};

                    final filteredDocs = docs.where((doc) {
                      final date = (doc['date'] as Timestamp).toDate();
                      return _isInRange(date) && doc['walletId'] == currentWallet?.id;
                    }).toList();

                    for (var doc in filteredDocs) {
                      if (doc['type'] == 'income') {
                        incomeFiltered += doc['amount'] as int;
                        incomeCategorySum[doc['category']] =
                            (incomeCategorySum[doc['category']] ?? 0) + (doc['amount'] as int).toDouble();
                      } else {
                        expenseFiltered += doc['amount'] as int;
                        expenseCategorySum[doc['category']] =
                            (expenseCategorySum[doc['category']] ?? 0) + (doc['amount'] as int).toDouble();
                      }
                    }

                    Map<String, double> chartData = _selectedSummary == 1 ? incomeCategorySum : expenseCategorySum;
                    final double total = chartData.values.fold(0.0, (a, b) => a + b);

                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [kPrimary, kPrimaryDark],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 7))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              DropdownButton<int>(
                                value: selectedWalletIndex, dropdownColor: kPrimaryDark,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                                items: List.generate(wallets.length, (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text(wallets[index].name,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                                onChanged: (v) { if (v != null) _onWalletChanged(v); },
                              ),
                              Row(children: [
                                if (wallets.length > 1)
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.white54), onPressed: _confirmDeleteWallet),
                                IconButton(icon: const Icon(Icons.add_circle, color: Colors.white), onPressed: _addWallet),
                              ]),
                            ]),
                            const SizedBox(height: 8),
                            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              if (currentWallet != null) Image.asset(currentWallet!.iconPath, width: 64, height: 64),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('ยอดเงินคงเหลือ', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('฿ $balance', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              ])),
                            ]),
                          ]),
                        ),

                        const SizedBox(height: 4),
                        QuestBannerList(activeGoalId: _activeQuestGoalId),

                        Card(
                          elevation: 0, color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              iconColor: kPrimary, collapsedIconColor: kPrimary,
                              title: Row(children: [
                                const Icon(Icons.bar_chart, color: kPrimary),
                                const SizedBox(width: 6),
                                const Expanded(child: Text('งบประมาณ',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText))),
                                if (activeBudget != null) ...[
                                  IconButton(icon: const Icon(Icons.edit, size: 20, color: kPrimaryDark),
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _showEditBudgetDialog),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 20),
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                      color: Colors.redAccent, onPressed: _confirmDeleteBudget),
                                ],
                              ]),
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      color: activeBudget == null ? Colors.grey.shade50 : _budgetCardColor(docs),
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(16),
                                  child: activeBudget == null ? _noBudgetUI() : _budgetUI(docs),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            _filterButton('วัน', FilterType.day),
                            _filterButton('สัปดาห์', FilterType.week),
                            _filterButton('เดือน', FilterType.month),
                          ]),
                        ),

                        const SizedBox(height: 16),

                        Row(children: [
                          _summaryCard('สรุปทั้งหมด', incomeFiltered - expenseFiltered, Colors.blue, 0),
                          _summaryCard('เงินเข้า', incomeFiltered, Colors.green, 1),
                          _summaryCard('เงินออก', expenseFiltered, Colors.red, 2),
                        ]),

                        const SizedBox(height: 24),

                        if (_selectedSummary == 0) ...[
                          Row(children: [
                            if (incomeCategorySum.isNotEmpty) Expanded(child: Column(children: [
                              const Text('เงินเข้า', style: TextStyle(fontWeight: FontWeight.bold, color: kText)),
                              const SizedBox(height: 8),
                              SizedBox(height: 160, child: PieChart(PieChartData(
                                centerSpaceRadius: 28,
                                pieTouchData: PieTouchData(touchCallback: (event, response) {
                                  if (event is! FlTapUpEvent) return;
                                  _showAllLegendPopup(title: 'เงินเข้า', data: incomeCategorySum, colors: incomeCategoryColors);
                                }),
                                sections: incomeCategorySum.entries.map((e) => PieChartSectionData(
                                    value: e.value, color: incomeCategoryColors[e.key] ?? Colors.grey, radius: 50, title: '')).toList(),
                              ))),
                            ])),
                            const SizedBox(width: 12),
                            if (expenseCategorySum.isNotEmpty) Expanded(child: Column(children: [
                              const Text('เงินออก', style: TextStyle(fontWeight: FontWeight.bold, color: kText)),
                              const SizedBox(height: 8),
                              SizedBox(height: 160, child: PieChart(PieChartData(
                                centerSpaceRadius: 28,
                                pieTouchData: PieTouchData(touchCallback: (event, response) {
                                  if (event is! FlTapUpEvent) return;
                                  _showAllLegendPopup(title: 'เงินออก', data: expenseCategorySum, colors: categoryColors);
                                }),
                                sections: expenseCategorySum.entries.map((e) => PieChartSectionData(
                                    value: e.value, color: categoryColors[e.key] ?? Colors.grey, radius: 50, title: '')).toList(),
                              ))),
                            ])),
                          ]),
                        ] else ...[
                          if (chartData.isNotEmpty) SizedBox(height: 230, child: PieChart(PieChartData(
                            sections: chartData.entries.map((e) {
                              final percent = (e.value / total) * 100;
                              return PieChartSectionData(
                                value: e.value,
                                color: _selectedSummary == 1 ? incomeCategoryColors[e.key] ?? Colors.grey : categoryColors[e.key] ?? Colors.grey,
                                radius: 90,
                                title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
                                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                            pieTouchData: PieTouchData(touchCallback: (event, response) {
                              if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) return;
                              _showAllLegendPopup(
                                title: _selectedSummary == 1 ? 'เงินเข้า' : 'เงินออก',
                                data: chartData,
                                colors: _selectedSummary == 1 ? incomeCategoryColors : categoryColors);
                            }),
                          ))),
                        ],

                        const SizedBox(height: 16),
                        if (filteredDocs.isEmpty)
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 20),
                            const SizedBox(width: 8),
                            Text('ยังไม่ได้ทำรายการ', style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
                            const Text('😉', style: TextStyle(fontSize: 30)),
                          ]),
                        const SizedBox(height: 16),
                      ]),
                    );
                  },
                ),
    );
  }

  Widget _noWalletUI() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/images/icon.png', width: 100, height: 100),
        const SizedBox(height: 24),
        const Text('ยินดีต้อนรับสู่ ปลูกเงิน! 🌱',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kText), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('เริ่มต้นด้วยการสร้างกระเป๋าเงินแรกของคุณ',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          icon: const Icon(Icons.add),
          label: const Text('สร้างกระเป๋าเงิน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _addWallet,
        )),
      ]),
    ));
  }

  Widget _filterButton(String text, FilterType type) {
    final selected = _filterType == type;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: selected ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
        child: Text(text, textAlign: TextAlign.center,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade600,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
      ),
    ));
  }

  Widget _summaryCard(String title, int amount, Color color, int index) {
    final selected = _selectedSummary == index;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _selectedSummary = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color.withOpacity(0.4) : Colors.grey.shade200, width: selected ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text('฿$amount', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ]),
      ),
    ));
  }

  void _showAllLegendPopup({required String title, required Map<String, double> data, required Map<String, Color> colors}) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    final total = data.values.fold(0.0, (a, b) => a + b);
    showDialog(
      context: context, barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('รวมทั้งหมด ฿ ${total.toInt()}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ]),
        content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: data.entries.map((e) {
          final percent = total == 0 ? 0 : (e.value / total) * 100;
          return Card(elevation: 1, margin: const EdgeInsets.symmetric(vertical: 6), child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('฿ ${e.value.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ]),
          ));
        }).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด'))],
      ),
    ).then((_) => _isDialogOpen = false);
  }

  Color _budgetCardColor(List<QueryDocumentSnapshot> docs) {
    final progress = _budgetProgress(docs);
    if (progress <= 0) return Colors.red.shade50;
    if (progress <= 0.25) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Widget _noBudgetUI() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ยังไม่ได้ตั้งงบประมาณสำหรับกระเป๋านี้', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryLight, foregroundColor: kPrimaryDark,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('เพิ่มงบประมาณ'),
        onPressed: _showAddBudgetDialog,
      ),
    ]);
  }

  Widget _budgetUI(List<QueryDocumentSnapshot> docs) {
    final progress = _budgetProgress(docs);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          RichText(text: TextSpan(children: [
            TextSpan(
              text: '฿ ${_remainingBudget(docs)}',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: progress > 0.5 ? kPrimaryDark : progress > 0.25 ? Colors.orange.shade700 : Colors.red.shade600),
            ),
            TextSpan(
              text: ' / ${activeBudget!.amount}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ])),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black26, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(children: [
              Container(height: 28, color: Colors.grey.shade200),
              LayoutBuilder(builder: (context, constraints) {
                final barColor = progress > 0.5 ? kPrimary : progress > 0.25 ? Colors.orange : Colors.red;
                final filledWidth = constraints.maxWidth * progress;
                final pct = (progress * 100).toInt();
                return Stack(clipBehavior: Clip.none, children: [
                  Container(height: 28, width: filledWidth, color: barColor),
                  SizedBox(
                    width: constraints.maxWidth, height: 28,
                    child: Center(child: Text('$pct%', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: filledWidth > constraints.maxWidth * 0.5 ? Colors.white : kText,
                    ))),
                  ),
                ]);
              }),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (progress <= 0.25 && progress > 0)
        const Row(children: [Icon(Icons.warning_amber, color: Colors.orange, size: 18), SizedBox(width: 6),
          Text('งบประมาณใกล้หมดแล้ว', style: TextStyle(color: Colors.orange))]),
      if (progress <= 0)
        const Row(children: [Icon(Icons.error, color: Colors.red, size: 18), SizedBox(width: 6),
          Text('งบประมาณหมดแล้ว', style: TextStyle(color: Colors.red))]),
    ]);
  }

  Future<bool> _showDeleteSheet({required String title, required String message,
      IconData icon = Icons.delete_outline, Color iconColor = Colors.redAccent}) async {
    final result = await showModalBottomSheet<bool>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
          Icon(icon, color: iconColor, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: iconColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), child: const Text('ลบ'))),
          ]),
        ]),
      ),
    );
    return result ?? false;
  }
}