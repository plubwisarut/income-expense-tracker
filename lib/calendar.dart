import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'auth_helper.dart';
import 'graph.dart';
import 'recent.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  Map<String, Map<String, double>> dailySummary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null).then((_) => _fetchMonthlyData());
  }

  Future<void> _fetchMonthlyData() async {
    setState(() => _isLoading = true);
    final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    final snapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('userID', isEqualTo: AuthHelper.uid)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    Map<String, Map<String, double>> temp = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final key = DateFormat('yyyy-MM-dd').format(date);
      temp[key] ??= {'income': 0, 'expense': 0};
      if (data['type'] == 'income') {
        temp[key]!['income'] = temp[key]!['income']! + (data['amount'] as num).toDouble();
      } else {
        temp[key]!['expense'] = temp[key]!['expense']! + (data['amount'] as num).toDouble();
      }
    }
    setState(() {
      dailySummary = temp;
      _isLoading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
    _fetchMonthlyData();
  }

  String _fmtShort(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startOffset = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final isCurrentMonth = today.year == _currentMonth.year && today.month == _currentMonth.month;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ปฏิทิน',
          style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Month navigator + summary card
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Month selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _navBtn(Icons.chevron_left, () => _changeMonth(-1)),
                      Text(
                        DateFormat('MMMM yyyy', 'th').format(_currentMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: kText,
                        ),
                      ),
                      _navBtn(Icons.chevron_right, () => _changeMonth(1)),
                    ],
                  ),
                ),

                // Weekday headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'].map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == 'อา' || d == 'ส'
                                ? Colors.red.shade300
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: Colors.grey.shade100),
              ],
            ),
          ),

          // Calendar grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.52,
                    ),
                    itemCount: daysInMonth + startOffset,
                    itemBuilder: (context, index) {
                      if (index < startOffset) return const SizedBox();

                      final day = index - startOffset + 1;
                      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                      final key = DateFormat('yyyy-MM-dd').format(date);
                      final data = dailySummary[key];
                      final income = data?['income'] ?? 0.0;
                      final expense = data?['expense'] ?? 0.0;
                      final net = income - expense;
                      final isToday = isCurrentMonth && today.day == day;
                      final hasData = data != null;
                      final colIndex = (index) % 7;
                      final isWeekend = colIndex == 0 || colIndex == 6;

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RecentScreen(initialDate: date)),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isToday
                                ? kPrimary
                                : hasData
                                    ? kPrimaryLight
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday
                                  ? kPrimary
                                  : hasData
                                      ? kPrimary.withOpacity(0.2)
                                      : Colors.grey.shade200,
                              width: isToday ? 0 : 1,
                            ),
                            boxShadow: isToday
                                ? [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Day number
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isToday
                                      ? Colors.white
                                      : isWeekend
                                          ? Colors.red.shade400
                                          : kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (hasData) ...[
                                if (income > 0)
                                  _amountTag(
                                    '+${_fmtShort(income)}',
                                    isToday ? Colors.white.withOpacity(0.9) : Colors.green.shade600,
                                  ),
                                if (expense > 0)
                                  _amountTag(
                                    '-${_fmtShort(expense)}',
                                    isToday ? Colors.white.withOpacity(0.85) : Colors.red.shade400,
                                  ),
                                const Spacer(),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? Colors.white.withOpacity(0.2)
                                        : net >= 0
                                            ? kPrimary.withOpacity(0.12)
                                            : Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _fmtShort(net.abs()),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isToday
                                          ? Colors.white
                                          : net >= 0
                                              ? kPrimaryDark
                                              : Colors.red.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimaryDark, size: 20),
        ),
      );

  Widget _amountTag(String text, Color color) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
      );
}