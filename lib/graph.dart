import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'doscreen.dart';
import 'calendar.dart';
import 'result.dart';
import 'goal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recent.dart';
import 'auth_helper.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

enum DateFilter { day, week, month, year }

class GraphScreen extends StatefulWidget {
  final DateTime? selectedDate;
  const GraphScreen({super.key, this.selectedDate});
  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateFilter _dateFilter = DateFilter.month;
  late DateTime _selectedDate;
  String? _selectedWalletId;
  List<QueryDocumentSnapshot> _wallets = [];
  bool _isLoadingWallets = true;

  static const _incomeColors = <String, Color>{
    'ค่าขนม': Colors.amber,
    'เงินเดือน': Colors.lightGreen,
    'งานเสริม': Colors.lightBlue,
    'โบนัส': Colors.teal,
    'ของขวัญ': Colors.pinkAccent,
    'อื่นๆ': Colors.grey,
  };

  static const _expenseColors = <String, Color>{
    'อาหาร': Colors.deepOrange,
    'ขนม/ของหวาน': Colors.purpleAccent,
    'น้ำหวาน/กาแฟ': Colors.brown,
    'เดินทาง': Colors.indigo,
    'ที่พัก': Colors.green,
    'ช้อปปิ้ง': Colors.purple,
    'บันเทิง': Colors.redAccent,
    'เติมเกม': Colors.red,
    'ค่าโทรศัพท์': kPrimary,
    'เสื้อผ้า': Colors.pink,
    'เครื่องสำอาง': Colors.pinkAccent,
    'สกินแคร์': Colors.lime,
    'ค่าเทอม': Colors.indigoAccent,
    'สังสรรค์': Colors.orange,
    'การแพทย์': Colors.cyan,
    'สัตว์เลี้ยง': Colors.greenAccent,
    'อื่นๆ': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = widget.selectedDate ?? DateTime.now();
    if (widget.selectedDate != null) _dateFilter = DateFilter.day;
    _loadWallets();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadWallets() async {
    final snap = await FirebaseFirestore.instance.collection('wallets').where('userID', isEqualTo: AuthHelper.uid).get();
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_wallet_id');
    setState(() {
      _wallets = snap.docs;
      _selectedWalletId = (lastId != null && snap.docs.any((w) => w.id == lastId))
          ? lastId : snap.docs.isNotEmpty ? snap.docs.first.id : null;
      _isLoadingWallets = false;
    });
  }

  bool _isInRange(DateTime date) {
    final d = _selectedDate;
    switch (_dateFilter) {
      case DateFilter.day:
        return date.year == d.year && date.month == d.month && date.day == d.day;
      case DateFilter.week:
        final s = d.subtract(Duration(days: d.weekday - 1));
        final e = s.add(const Duration(days: 6));
        return !date.isBefore(DateTime(s.year, s.month, s.day)) &&
               !date.isAfter(DateTime(e.year, e.month, e.day, 23, 59, 59));
      case DateFilter.month:
        return date.year == d.year && date.month == d.month;
      case DateFilter.year:
        return date.year == d.year;
    }
  }

  Future<void> _pickDate() async {
    final isMonth = _dateFilter == DateFilter.month;
    int tempYear = _selectedDate.year, tempMonth = _selectedDate.month;
    await showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: kPrimaryDark), onPressed: () => setM(() => tempYear--)),
            Text('$tempYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
            IconButton(icon: const Icon(Icons.chevron_right, color: kPrimaryDark), onPressed: () => setM(() => tempYear++)),
          ]),
          if (isMonth) ...[
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2),
              itemCount: 12,
              itemBuilder: (_, i) {
                final sel = tempMonth == i + 1;
                return GestureDetector(
                  onTap: () => setM(() => tempMonth = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150), alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? kPrimary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(_monthLabel(DateTime(tempYear, i + 1)),
                      style: TextStyle(color: sel ? Colors.white : Colors.black87,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              setState(() => _selectedDate = DateTime(tempYear, isMonth ? tempMonth : _selectedDate.month, 1));
              Navigator.pop(ctx);
            },
            child: const Text('ตกลง', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
      )),
    );
  }

  Widget _summaryRow(List<QueryDocumentSnapshot> docs) {
    int income = 0, expense = 0;
    for (var d in docs) {
      final amt = (d['amount'] as num).toInt();
      if (d['type'] == 'income') income += amt; else expense += amt;
    }
    final net = income - expense;
    return Row(children: [
      _summaryBox('รายรับ', income, Colors.green), const SizedBox(width: 8),
      _summaryBox('รายจ่าย', expense, Colors.red), const SizedBox(width: 8),
      _summaryBox('คงเหลือ', net, net >= 0 ? kPrimary : Colors.orange),
    ]);
  }

  Widget _summaryBox(String label, int amount, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('฿${_fmt(amount)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );

  Widget _lineChartSection(List<QueryDocumentSnapshot> allDocs) {
    final target = _selectedDate;
    final isYear = _dateFilter == DateFilter.year;
    final count = isYear ? 12 : DateUtils.getDaysInMonth(target.year, target.month);
    final Map<int, double> incMap = {}, expMap = {};
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId) continue;
      final date = (doc['date'] as Timestamp).toDate();
      final amt = (doc['amount'] as num).toDouble();
      if (isYear) {
        if (date.year != target.year) continue;
        final k = date.month;
        if (doc['type'] == 'income') incMap[k] = (incMap[k] ?? 0) + amt;
        else expMap[k] = (expMap[k] ?? 0) + amt;
      } else {
        if (date.year != target.year || date.month != target.month) continue;
        final k = date.day;
        if (doc['type'] == 'income') incMap[k] = (incMap[k] ?? 0) + amt;
        else expMap[k] = (expMap[k] ?? 0) + amt;
      }
    }
    final incSpots = List.generate(count, (i) => FlSpot((i+1).toDouble(), incMap[i+1] ?? 0));
    final expSpots = List.generate(count, (i) => FlSpot((i+1).toDouble(), expMap[i+1] ?? 0));
    final title = isYear ? 'รายรับ-รายจ่ายรายเดือน (${target.year})'
        : 'รายรับ-รายจ่ายรายวัน (${_monthLabel(target)} ${target.year})';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kText)),
        const SizedBox(height: 8),
        Row(children: [_legendDot(Colors.green, 'รายรับ'), const SizedBox(width: 16), _legendDot(Colors.red, 'รายจ่าย')]),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
              getTitlesWidget: (v, _) => Text(_fmtShort(v.toInt()), style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: isYear ? 1 : 5,
              getTitlesWidget: (v, _) {
                if (isYear) {
                  final i = v.toInt() - 1;
                  if (i < 0 || i >= 12) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(_monthLabel(DateTime(target.year, i+1)).replaceAll('.',''), style: const TextStyle(fontSize: 9)));
                }
                return Text('${v.toInt()}', style: const TextStyle(fontSize: 10));
              })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(spots: incSpots, isCurved: true, color: Colors.green, barWidth: 2,
              dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.08))),
            LineChartBarData(spots: expSpots, isCurved: true, color: Colors.red, barWidth: 2,
              dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.08))),
          ],
        ))),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 12)),
  ]);

  Widget _pieSection(List<QueryDocumentSnapshot> docs) {
    final Map<String, double> incSum = {}, expSum = {};
    for (var doc in docs) {
      final cat = doc['category'] as String;
      final amt = (doc['amount'] as num).toDouble();
      if (doc['type'] == 'income') incSum[cat] = (incSum[cat] ?? 0) + amt;
      else expSum[cat] = (expSum[cat] ?? 0) + amt;
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _pieBlock(incSum, 'รายรับ', true)), const SizedBox(width: 12),
      Expanded(child: _pieBlock(expSum, 'รายจ่าย', false)),
    ]);
  }

  Widget _pieBlock(Map<String, double> data, String label, bool isIncome) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    final colors = isIncome ? _incomeColors : _expenseColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0,2))]),
      child: Column(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kText)),
        const SizedBox(height: 8),
        SizedBox(height: 150, child: data.isEmpty
          ? Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey.shade400)))
          : PieChart(PieChartData(centerSpaceRadius: 28, sectionsSpace: 2,
              sections: data.entries.map((e) => PieChartSectionData(
                value: e.value, color: colors[e.key] ?? Colors.grey, radius: 50,
                title: total == 0 ? '' : '${(e.value/total*100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              )).toList()))),
        const SizedBox(height: 8),
        ...data.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Text('฿${_fmt(e.value.toInt())}', style: const TextStyle(fontSize: 11)),
        ]))),
      ]),
    );
  }

  Widget _topCategorySection(List<QueryDocumentSnapshot> allDocs) {
    final target = _selectedDate;
    final isYear = _dateFilter == DateFilter.year;
    final Map<String, double> catMap = {};
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId || doc['type'] != 'expense') continue;
      final date = (doc['date'] as Timestamp).toDate();
      if (isYear ? date.year != target.year : (date.year != target.year || date.month != target.month)) continue;
      final cat = doc['category'] as String;
      catMap[cat] = (catMap[cat] ?? 0) + (doc['amount'] as num).toDouble();
    }
    String topCat = '-'; double topAmt = 0;
    catMap.forEach((c, a) { if (a > topAmt) { topAmt = a; topCat = c; } });
    final period = isYear ? 'ปี ${target.year}' : '${_monthLabel(target)} ${target.year}';
    return _sectionCard(icon: Icons.emoji_events, iconColor: Colors.amber,
      title: 'หมวดที่ใช้เยอะสุด ($period)',
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200)),
            child: Text(topCat, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800, fontSize: 15))),
          const SizedBox(width: 12),
          Text('฿${_fmt(topAmt.toInt())}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        ]),
        const SizedBox(height: 12),
        ...(() {
          final sorted = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final top5 = sorted.take(5).toList();
          final maxVal = top5.isEmpty ? 1.0 : top5.first.value;
          return top5.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: e.value / maxVal, minHeight: 10,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(_expenseColors[e.key] ?? kPrimary)))),
            const SizedBox(width: 8),
            Text('฿${_fmt(e.value.toInt())}', style: const TextStyle(fontSize: 11)),
          ])));
        })(),
      ]),
    );
  }

  Widget _peakSpendingSection(List<QueryDocumentSnapshot> allDocs) {
    final target = _selectedDate;
    final isYear = _dateFilter == DateFilter.year;
    final Map<int, double> expMap = {};
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId || doc['type'] != 'expense') continue;
      final cat = doc['category'] as String;
      final date = (doc['date'] as Timestamp).toDate();
      final amt = (doc['amount'] as num).toDouble();
      if (isYear) { if (date.year != target.year) continue; expMap[date.month] = (expMap[date.month] ?? 0) + amt; }
      else { if (date.year != target.year || date.month != target.month) continue; expMap[date.day] = (expMap[date.day] ?? 0) + amt; }
    }
    int peakKey = 0; double peakAmt = 0;
    expMap.forEach((k, a) { if (a > peakAmt) { peakAmt = a; peakKey = k; } });
    final peakLabel = isYear ? (peakKey > 0 ? _monthLabel(DateTime(target.year, peakKey)) : '-') : 'วันที่ $peakKey';
    double sum(bool Function(int) f) => expMap.entries.where((e) => f(e.key)).fold(0.0, (a, b) => a + b.value);
    return _sectionCard(icon: Icons.access_time, iconColor: Colors.indigo,
      title: 'ช่วงที่ใช้เงินเยอะสุด (${isYear ? 'ปี ${target.year}' : '${_monthLabel(target)} ${target.year}'})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (peakKey > 0) Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo.shade100)),
            child: Text(peakLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700, fontSize: 15))),
          const SizedBox(width: 12),
          Text('฿${_fmt(peakAmt.toInt())}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ]) else Text('ยังไม่มีข้อมูล', style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 12),
        Row(children: isYear ? [
          _periodBox('ต้นปี', 'ม.ค.-เม.ย.', sum((k) => k <= 4).toInt()), const SizedBox(width: 8),
          _periodBox('กลางปี', 'พ.ค.-ส.ค.', sum((k) => k >= 5 && k <= 8).toInt()), const SizedBox(width: 8),
          _periodBox('ปลายปี', 'ก.ย.-ธ.ค.', sum((k) => k >= 9).toInt()),
        ] : [
          _periodBox('ต้นเดือน', '1-10', sum((k) => k <= 10).toInt()), const SizedBox(width: 8),
          _periodBox('กลางเดือน', '11-20', sum((k) => k >= 11 && k <= 20).toInt()), const SizedBox(width: 8),
          _periodBox('ปลายเดือน', '21+', sum((k) => k >= 21).toInt()),
        ]),
      ]),
    );
  }

  Widget _monthCompareSection(List<QueryDocumentSnapshot> allDocs) {
    final target = _selectedDate;
    final prev = DateTime(target.year, target.month - 1);
    final Map<String, double> thisCat = {}, lastCat = {};
    int thisExp = 0, lastExp = 0;
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId || doc['type'] != 'expense') continue;
      final cat = doc['category'] as String;
      final date = (doc['date'] as Timestamp).toDate();
      final amt = (doc['amount'] as num).toDouble();
      if (date.year == target.year && date.month == target.month) { thisCat[cat] = (thisCat[cat] ?? 0) + amt; thisExp += amt.toInt(); }
      else if (date.year == prev.year && date.month == prev.month) { lastCat[cat] = (lastCat[cat] ?? 0) + amt; lastExp += amt.toInt(); }
    }
    final changes = <Map<String, dynamic>>[];
    for (var cat in {...thisCat.keys, ...lastCat.keys}) {
      final t = thisCat[cat] ?? 0, l = lastCat[cat] ?? 0;
      if (t > 0 || l > 0) changes.add({'cat': cat, 'this': t, 'diff': t - l});
    }
    changes.sort((a, b) => (b['diff'] as double).abs().compareTo((a['diff'] as double).abs()));
    return _sectionCard(icon: Icons.compare_arrows, iconColor: kPrimary,
      title: 'เทียบ ${_monthLabel(target)} กับเดือนก่อน',
      child: Column(children: [
        Row(children: [
          Expanded(child: _compareBox('เดือนนี้', thisExp, Colors.red)), const SizedBox(width: 8),
          Expanded(child: _compareBox('เดือนก่อน', lastExp, Colors.grey)), const SizedBox(width: 8),
          Expanded(child: _compareBox('ต่าง', thisExp - lastExp, thisExp <= lastExp ? kPrimary : Colors.red, showSign: true)),
        ]),
        if (changes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft,
            child: Text('การเปลี่ยนแปลงรายหมวด', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 8),
          ...changes.take(5).map((c) {
            final diff = c['diff'] as double; final isUp = diff > 0;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: isUp ? Colors.red : kPrimary),
              const SizedBox(width: 6),
              Expanded(child: Text(c['cat'], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              Text('฿${_fmt((c['this'] as double).toInt())}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isUp ? Colors.red.shade50 : kPrimaryLight, borderRadius: BorderRadius.circular(6)),
                child: Text('${isUp ? '+' : ''}${_fmt(diff.toInt())}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUp ? Colors.red : kPrimaryDark))),
            ]));
          }),
        ],
      ]),
    );
  }

  Widget _compareReport(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    final labels = <String>[], incData = <double>[], expData = <double>[];
    for (int i = 5; i >= 0; i--) {
      final t = DateTime(now.year, now.month - i);
      double inc = 0, exp = 0;
      for (var doc in allDocs) {
        if (doc['walletId'] != _selectedWalletId) continue;
        final date = (doc['date'] as Timestamp).toDate();
        if (date.year == t.year && date.month == t.month) {
          final amt = (doc['amount'] as num).toDouble();
          if (doc['type'] == 'income') inc += amt; else exp += amt;
        }
      }
      labels.add(_monthLabel(t)); incData.add(inc); expData.add(exp);
    }
    final maxY = [...incData, ...expData].fold(0.0, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0,2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('เปรียบเทียบ 6 เดือนย้อนหลัง', style: TextStyle(fontWeight: FontWeight.bold, color: kText)),
          const SizedBox(height: 8),
          Row(children: [_legendDot(Colors.green, 'รายรับ'), const SizedBox(width: 16), _legendDot(Colors.red, 'รายจ่าย')]),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: BarChart(BarChartData(
            maxY: maxY * 1.2,
            barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: incData[i], color: Colors.green, width: 10, borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: expData[i], color: Colors.red, width: 10, borderRadius: BorderRadius.circular(4)),
            ])),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[v.toInt()], style: const TextStyle(fontSize: 10))))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                getTitlesWidget: (v, _) => Text(_fmtShort(v.toInt()), style: const TextStyle(fontSize: 10)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
          ))),
        ])),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0,2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('สรุปรายเดือน', style: TextStyle(fontWeight: FontWeight.bold, color: kText)),
          const SizedBox(height: 12),
          Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
            children: [
              TableRow(decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(8)),
                children: ['เดือน','รายรับ','รายจ่าย','คงเหลือ'].map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text(h, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryDark)))).toList()),
              ...List.generate(6, (i) {
                final net = incData[i] - expData[i];
                return TableRow(children: [
                  _tableCell(labels[i]), _tableCell('฿${_fmt(incData[i].toInt())}', color: Colors.green),
                  _tableCell('฿${_fmt(expData[i].toInt())}', color: Colors.red),
                  _tableCell('฿${_fmt(net.toInt())}', color: net >= 0 ? kPrimary : Colors.orange),
                ]);
              }),
            ]),
        ])),
    ]);
  }

  Widget _tableCell(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(text, style: TextStyle(fontSize: 13, color: color ?? kText), overflow: TextOverflow.ellipsis));

  Widget _behaviorTab(List<QueryDocumentSnapshot> allDocs) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _walletDropdown(),
      const SizedBox(height: 16), _savingsRecommendationSection(allDocs),
      const SizedBox(height: 16), _goalCompareSection(allDocs),
      const SizedBox(height: 16), _forecastSection(allDocs),
      const SizedBox(height: 16),
    ]),
  );

  Widget _savingsRecommendationSection(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    double totalIncome = 0;
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId) continue;
      final date = (doc['date'] as Timestamp).toDate();
      if ((now.year - date.year) * 12 + (now.month - date.month) >= 3) continue;
      if (doc['type'] == 'income') totalIncome += (doc['amount'] as num).toDouble();
    }
    final avg = totalIncome / 3;
    final rule50 = avg * 0.5, rule30 = avg * 0.3, rule20 = avg * 0.2;
    return _sectionCard(icon: Icons.savings_outlined, iconColor: Colors.green.shade700,
      title: 'แนะนำการออมเงิน',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 14),
        const Text('แนะนำการจัดสรรรายรับ (50/30/20)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),
        _rule503020Bar(label: 'จำเป็น 50%', recommended: rule50, color: Colors.blue.shade400,
          icon: Icons.home_outlined, description: 'อาหาร เดินทาง ที่พัก ค่าโทรศัพท์'),
        const SizedBox(height: 8),
        _rule503020Bar(label: 'ต้องการ 30%', recommended: rule30, color: Colors.orange.shade400,
          icon: Icons.shopping_bag_outlined, description: 'ช้อปปิ้ง บันเทิง สังสรรค์'),
        const SizedBox(height: 8),
        _rule503020Bar(label: 'ออม/ลงทุน 20%', recommended: rule20, color: kPrimary,
          icon: Icons.savings_outlined, description: 'เป้าหมายการออมที่แนะนำ', highlight: true),
      ]),
    );
  }

  Widget _rule503020Bar({required String label, required double recommended, required Color color,
      required IconData icon, required String description, bool highlight = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? kPrimaryLight : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? kPrimary.withOpacity(0.4) : Colors.grey.shade200, width: highlight ? 1.5 : 1)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: highlight ? kPrimaryDark : Colors.black87)),
          Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ])),
        Text('฿${_fmt(recommended.toInt())}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );

  Widget _goalCompareSection(List<QueryDocumentSnapshot> allDocs) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('goals')
          .where('userID', isEqualTo: AuthHelper.uid)
          .orderBy('createdAt').limit(1).get(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _sectionCard(icon: Icons.flag_outlined, iconColor: Colors.purple,
            title: 'ก่อน/หลังตั้งเป้าหมายการออม',
            child: Text('ยังไม่มีเป้าหมายการออม', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)));
        }
        final goalStart = ((snap.data!.docs.first.data() as Map)['createdAt'] as Timestamp).toDate();
        final Map<String, double> before = {}, after = {};
        for (var doc in allDocs) {
          if (doc['walletId'] != _selectedWalletId || doc['type'] != 'expense') continue;
          final cat = doc['category'] as String;
          final date = (doc['date'] as Timestamp).toDate();
          final amt = (doc['amount'] as num).toDouble();
          final key = '${date.year}-${date.month.toString().padLeft(2,'0')}';
          if (date.isBefore(goalStart)) before[key] = (before[key] ?? 0) + amt;
          else after[key] = (after[key] ?? 0) + amt;
        }
        final beforeAvg = before.isEmpty ? 0.0 : before.values.fold(0.0,(a,b)=>a+b)/before.length;
        final afterAvg = after.isEmpty ? 0.0 : after.values.fold(0.0,(a,b)=>a+b)/after.length;
        final diff = afterAvg - beforeAvg; final improved = diff < 0;
        return _sectionCard(icon: Icons.flag_outlined, iconColor: Colors.purple,
          title: 'ก่อน/หลังตั้งเป้าหมายการออม',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ตั้งเป้าหมายเมื่อ: ${goalStart.day}/${goalStart.month}/${goalStart.year}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _compareBox('ก่อนตั้งเป้า', beforeAvg.toInt(), Colors.grey, subtitle: 'เฉลี่ย/เดือน')),
              const SizedBox(width: 8),
              Expanded(child: _compareBox('หลังตั้งเป้า', afterAvg.toInt(), Colors.purple, subtitle: 'เฉลี่ย/เดือน')),
              const SizedBox(width: 8),
              Expanded(child: _compareBox('เปลี่ยนไป', diff.toInt(), improved ? kPrimary : Colors.red, showSign: true)),
            ]),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: improved ? kPrimaryLight : Colors.orange.shade50, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: improved ? kPrimary.withOpacity(0.3) : Colors.orange.shade200)),
              child: Row(children: [
                Icon(improved ? Icons.trending_down : Icons.trending_up, color: improved ? kPrimary : Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  improved ? 'หลังตั้งเป้าหมาย รายจ่ายเฉลี่ยลดลง ฿${_fmt(diff.abs().toInt())}/เดือน 🎉'
                           : 'หลังตั้งเป้าหมาย รายจ่ายเฉลี่ยยังเพิ่มขึ้น ฿${_fmt(diff.abs().toInt())}/เดือน',
                  style: TextStyle(fontSize: 13, color: improved ? kPrimaryDark : Colors.orange.shade700))),
              ])),
          ]));
      },
    );
  }

  Widget _forecastSection(List<QueryDocumentSnapshot> allDocs) {
    final now = DateTime.now();
    double inc = 0, exp = 0;
    for (var doc in allDocs) {
      if (doc['walletId'] != _selectedWalletId) continue;
      final date = (doc['date'] as Timestamp).toDate();
      if ((now.year - date.year) * 12 + (now.month - date.month) >= 3) continue;
      final cat = doc['category'] as String;
      final amt = (doc['amount'] as num).toDouble();
      if (doc['type'] == 'income') inc += amt; else exp += amt;
    }
    final avgInc = inc/3, avgExp = exp/3, avgNet = avgInc - avgExp;
    return _sectionCard(icon: Icons.auto_graph, iconColor: Colors.blue,
      title: 'คาดการณ์อนาคต (3 เดือนล่าสุด)',
      child: Column(children: [
        Row(children: [
          _summaryBox('รายรับ/เดือน', avgInc.toInt(), Colors.green), const SizedBox(width: 8),
          _summaryBox('รายจ่าย/เดือน', avgExp.toInt(), Colors.red), const SizedBox(width: 8),
          _summaryBox('เหลือ/เดือน', avgNet.toInt(), avgNet >= 0 ? kPrimary : Colors.orange),
        ]),
        const SizedBox(height: 12),
        if (avgNet < 0)
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200)),
            child: const Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 18), SizedBox(width: 8),
              Expanded(child: Text('รายจ่ายมากกว่ารายรับ หากยังใช้แบบนี้ต่อไปเงินจะหมดเร็วขึ้นเรื่อยๆ',
                style: TextStyle(fontSize: 13, color: Colors.orange))),
            ]))
        else ...List.generate(3, (i) {
          final periods = ['3 เดือน','6 เดือน','12 เดือน'];
          final mults = [3, 6, 12];
          return Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 6), child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('ถ้าออมต่อ ${periods[i]}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('≈ ฿${_fmt((avgNet * mults[i]).toInt())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimary)),
            ]));
        }),
      ]),
    );
  }

  Widget _budgetOverrunSection() {
    if (_selectedWalletId == null) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('budgets').doc(_selectedWalletId).get(),
      builder: (ctx, budgetSnap) {
        if (!budgetSnap.hasData || !budgetSnap.data!.exists) return const SizedBox();
        final budgetAmount = ((budgetSnap.data!.data() as Map)['amount'] as num).toDouble();
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('transactions')
              .where('userID', isEqualTo: AuthHelper.uid)
              .where('walletId', isEqualTo: _selectedWalletId)
              .where('type', isEqualTo: 'expense').get(),
          builder: (ctx, txSnap) {
            if (!txSnap.hasData) return const SizedBox();
            final now = DateTime.now();
            int overrun = 0, onTrack = 0;
            for (int i = 5; i >= 0; i--) {
              final t = DateTime(now.year, now.month - i);
              final total = txSnap.data!.docs.where((doc) {
                final d = (doc['date'] as Timestamp).toDate();
                final cat = doc['category'] as String;
                return d.year == t.year && d.month == t.month;
              }).fold(0.0, (s, doc) => s + (doc['amount'] as num).toDouble());
              if (total > budgetAmount) overrun++; else onTrack++;
            }
            return _sectionCard(
              icon: Icons.warning_amber_rounded,
              iconColor: overrun > 0 ? Colors.red : kPrimary,
              title: 'สรุปการใช้งบประมาณ (6 เดือน)',
              child: Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100)),
                  child: Column(children: [
                    Text('$overrun', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
                    const SizedBox(height: 4),
                    Text('เดือนที่เกินงบ', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                  ]))),
                const SizedBox(width: 12),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withOpacity(0.2))),
                  child: Column(children: [
                    Text('$onTrack', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kPrimaryDark)),
                    const SizedBox(height: 4),
                    Text('เดือนที่อยู่ในงบ', style: TextStyle(fontSize: 12, color: kPrimary.withOpacity(0.7))),
                  ]))),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _sectionCard({required IconData icon, required Color iconColor, required String title, required Widget child}) =>
    Container(width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: iconColor, size: 18), const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kText))]),
        const SizedBox(height: 14), child,
      ]));

  Widget _periodBox(String label, String range, int amount) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kPrimaryDark, fontWeight: FontWeight.w600)),
        Text(range, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('฿${_fmt(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryDark)),
      ])));

  Widget _compareBox(String label, int amount, Color color, {bool showSign = false, String? subtitle}) {
    final sign = showSign && amount > 0 ? '+' : '';
    return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('$sign฿${_fmt(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ]));
  }

  Widget _emptyState(String period) => Center(
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 90, height: 90, decoration: BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
          child: const Icon(Icons.bar_chart_outlined, size: 48, color: kPrimary)),
        const SizedBox(height: 16),
        Text('ไม่มีข้อมูล', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Text('ยังไม่มีธุรกรรมใน$period', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ])));

  Widget _walletDropdown({String? label}) => DropdownButtonFormField<String>(
    value: _selectedWalletId,
    decoration: InputDecoration(labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary)),
      filled: true, fillColor: Colors.white),
    items: _wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w['name'], overflow: TextOverflow.ellipsis))).toList(),
    onChanged: (v) => setState(() => _selectedWalletId = v));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('สถิติ', style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          indicatorWeight: 3,
          tabs: const [Tab(text: 'รายงาน'), Tab(text: 'เปรียบเทียบ'), Tab(text: 'พฤติกรรม')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: kPrimaryDark),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3, type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary, unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (i) {
          if (i == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
          else if (i == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RecentScreen()));
          else if (i == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const DoScreen()));
          else if (i == 4) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoalScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ภาพรวม'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'ธุรกรรม'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 46, color: kPrimary), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'สถิติ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_open), label: 'เมนู'),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transactions')
            .where('userID', isEqualTo: AuthHelper.uid).snapshots(),
        builder: (ctx, snapshot) {
          if (_isLoadingWallets) return const Center(child: CircularProgressIndicator(color: kPrimary));
          if (_wallets.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('ยังไม่มีกระเป๋าเงิน', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
              const SizedBox(height: 8),
              Text('กลับไปสร้างกระเป๋าเงินที่หน้าหลักก่อนนะครับ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ]));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
          final allDocs = snapshot.data!.docs;
          final filtered = allDocs.where((doc) {
            final date = (doc['date'] as Timestamp).toDate();
            return _isInRange(date) && doc['walletId'] == _selectedWalletId;
          }).toList();

          return TabBarView(controller: _tabController, children: [

            SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<DateFilter>(
                  value: _dateFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary)),
                    filled: true, fillColor: Colors.white),
                  items: const [
                    DropdownMenuItem(value: DateFilter.day, child: Text('วันนี้')),
                    DropdownMenuItem(value: DateFilter.week, child: Text('สัปดาห์นี้')),
                    DropdownMenuItem(value: DateFilter.month, child: Text('เดือนนี้')),
                    DropdownMenuItem(value: DateFilter.year, child: Text('ปีนี้')),
                  ],
                  onChanged: (v) => setState(() => _dateFilter = v ?? _dateFilter))),
                const SizedBox(width: 8),
                Expanded(child: _walletDropdown()),
              ]),
              if (_dateFilter == DateFilter.month || _dateFilter == DateFilter.year) ...[
                const SizedBox(height: 8),
                GestureDetector(onTap: _pickDate, child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withOpacity(0.3))),
                  child: Row(children: [
                    Icon(Icons.calendar_month, size: 16, color: kPrimaryDark), const SizedBox(width: 8),
                    Text(_dateFilter == DateFilter.month
                      ? '${_monthLabel(_selectedDate)} ${_selectedDate.year}' : '${_selectedDate.year}',
                      style: const TextStyle(color: kPrimaryDark, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.edit_calendar, size: 14, color: kPrimary.withOpacity(0.6)),
                  ]))),
              ],
              const SizedBox(height: 12),
              _summaryRow(filtered),
              const SizedBox(height: 16),
              _lineChartSection(allDocs),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _emptyState(_dateFilter == DateFilter.month
                  ? '${_monthLabel(_selectedDate)} ${_selectedDate.year}'
                  : _dateFilter == DateFilter.year ? 'ปี ${_selectedDate.year}' : 'ช่วงนี้')
              else ...[
                _pieSection(filtered), const SizedBox(height: 16),
                _topCategorySection(allDocs), const SizedBox(height: 16),
                _peakSpendingSection(allDocs), const SizedBox(height: 16),
                _monthCompareSection(allDocs), const SizedBox(height: 16),
              ],
              _budgetOverrunSection(), const SizedBox(height: 16),
            ])),

            SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              _walletDropdown(label: 'กระเป๋าเงิน'),
              const SizedBox(height: 16), _compareReport(allDocs), const SizedBox(height: 16),
            ])),

            _behaviorTab(allDocs),
          ]);
        },
      ),
    );
  }

  String _fmt(int n) {
    if (n.abs() >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n/1000).toStringAsFixed(1)}K';
    return n.toString();
  }
  String _fmtShort(int n) => n >= 1000 ? '${(n/1000).toStringAsFixed(0)}K' : n.toString();
  String _monthLabel(DateTime d) =>
    ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'][d.month-1];
}