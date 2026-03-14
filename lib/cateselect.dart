import 'package:flutter/material.dart';

const kPrimary = Color(0xFF43B89C);
const kPrimaryDark = Color(0xFF2E8B74);
const kPrimaryLight = Color(0xFFE8F7F4);
const kBackground = Color(0xFFF7FAFA);
const kText = Color(0xFF1A2E2B);

class CateSelectScreen extends StatelessWidget {
  CateSelectScreen({super.key});

  final Map<String, String> categories = {
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
          'เลือกหมวดหมู่',
          style: TextStyle(
            color: kText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final entry = categories.entries.elementAt(index);

          return GestureDetector(
            onTap: () {
              Navigator.pop(context, {
                'name': entry.key,
                'icon': entry.value,
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    entry.value,
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kText,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}