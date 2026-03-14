import 'package:flutter/material.dart';
import 'doscreen.dart';
import 'result.dart';
import 'graph.dart';
import 'setgoal.dart';
import 'sumson.dart';
import 'showquest.dart';
import 'sliphis.dart';
import 'event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recent.dart';
import 'auth_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('เมนู',
            style: TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _menuCard(
            imagePath: 'assets/images/setgoal.png',
            title: 'ตั้งเป้าหมายการออม',
            subtitle: 'วางแผนและติดตามเป้าหมายของคุณ',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SetGoalScreen())),
          ),
          const SizedBox(height: 12),

          _menuCard(
            imagePath: 'assets/images/mission.png',
            title: 'ภารกิจการออม',
            subtitle: 'งดรายจ่ายฟุ่มเฟือย สะสมเงินออม',
            onTap: () async {
              final snap = await FirebaseFirestore.instance
                  .collection('goals')
                  .where('userID', isEqualTo: AuthHelper.uid)
                  .where('questEnabled', isEqualTo: true)
                  .limit(1)
                  .get();
              if (!context.mounted) return;
              if (snap.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('ยังไม่มีเป้าหมายที่เปิดใช้ภารกิจ'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: kPrimaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
                return;
              }
              final doc = snap.docs.first;
              final data = doc.data() as Map<String, dynamic>;
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => QuestScreen(goalId: doc.id, goalTitle: data['title'])));
            },
          ),
          const SizedBox(height: 12),

          _menuCard(
            imagePath: 'assets/images/sumson.png',
            title: 'รายการรายรับ–รายจ่ายซ้ำ',
            subtitle: 'จัดการรายการที่เกิดซ้ำอัตโนมัติ',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SumsonScreen())),
          ),
          const SizedBox(height: 12),

          _menuCard(
            imagePath: 'assets/images/event.png',
            title: 'จัดการกิจกรรม',
            subtitle: 'วางแผนงบประมาณงานและกิจกรรมต่างๆ',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EventScreen())),
          ),
          const SizedBox(height: 12),

          _menuCard(
            imagePath: 'assets/images/slip.png',
            title: 'สลิปที่แนบไว้',
            subtitle: 'ดูสลิปย้อนหลังทั้งหมด',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SlipHistoryScreen())),
          ),
          const SizedBox(height: 12),

          _menuCard(
            imagePath: 'assets/images/logout.png',
            title: 'ออกจากระบบ',
            subtitle: null,
            titleColor: Colors.red,
            isDestructive: true,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false);
            },
          ),

          const SizedBox(height: 24),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
          else if (index == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RecentScreen()));
          else if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const DoScreen()));
          else if (index == 3) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GraphScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ภาพรวม'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'ธุรกรรม'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 46, color: kPrimary), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'สถิติ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_open), label: 'เมนู'),
        ],
      ),
    );
  }

  Widget _menuCard({
    required String imagePath,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Image.asset(imagePath, width: 64, height: 64, fit: BoxFit.contain),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: titleColor ?? kText)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ])),
            Icon(Icons.chevron_right,
                color: isDestructive ? Colors.red.shade300 : Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}