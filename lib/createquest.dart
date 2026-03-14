import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

const List<String> dailyHabitCategories = [
  'น้ำหวาน/กาแฟ',
  'ขนม/ของหวาน',
  'เติมเกม',
  'บันเทิง',
];

const List<String> spendingLimitCategories = [
  'เสื้อผ้า',
  'เครื่องสำอาง',
  'สกินแคร์',
  'ช้อปปิ้ง',
  'สังสรรค์',
];

// หมวดหมู่สำหรับ self_compare
const List<String> selfCompareCategories = [
  'อาหาร',
  'ช้อปปิ้ง',
  'บันเทิง',
  'สังสรรค์',
  'เดินทาง',
];

const int kDailyTriggerCount = 5;
const int kLimitTriggerCount = 2;
const int kSelfCompareTriggerCount = 4; // ต้องมีธุรกรรมอย่างน้อย 4 ครั้งใน 60 วัน
const int kHabitBonusAmount = 50; // โบนัสเมื่อบันทึกครบ 7 วัน

class QuestService {
  static final _db = FirebaseFirestore.instance;

  // ─── เรียกตอนผู้ใช้ toggle เปิด quest ใน goal ────────────────────────────
  static Future<void> activateQuestForGoal(String goalId) async {
    final activeQuests = await _db
        .collection('quests')
        .where('status', isEqualTo: 'active')
        .get();
    for (var doc in activeQuests.docs) {
      if (doc['goalId'] != goalId) {
        await doc.reference.update({'status': 'cancelled'});
      }
    }

    final allGoals = await _db.collection('goals').get();
    for (var doc in allGoals.docs) {
      if (doc.id != goalId) {
        await doc.reference.update({'questEnabled': false});
      }
    }

    await _db.collection('goals').doc(goalId).update({'questEnabled': true});
    await generateQuestsForGoal(goalId);
  }

  // ─── วิเคราะห์ transaction และสร้าง quest candidates ────────────────────
  static Future<void> generateQuestsForGoal(String goalId) async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 60));
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final goalDoc = await _db.collection('goals').doc(goalId).get();
    if (!goalDoc.exists) return;

    final goalData = goalDoc.data()!;
    final endDate = (goalData['endDate'] as Timestamp).toDate();
    final durationDays = endDate.difference(now).inDays;

    final snap = await _db
        .collection('transactions')
        .where('userID', isEqualTo: uid)
        .where('type', isEqualTo: 'expense')
        .where('date', isGreaterThan: Timestamp.fromDate(since))
        .get();

    final Map<String, List<int>> grouped = {};
    for (var doc in snap.docs) {
      final cat = doc['category'] as String;
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add((doc['amount'] as num).toInt());
    }

    // ── daily quest (เดิม) ──────────────────────────────────────────────────
    for (var cat in dailyHabitCategories) {
      final entries = grouped[cat] ?? [];
      if (entries.length >= kDailyTriggerCount) {
        final avg = entries.reduce((a, b) => a + b) ~/ entries.length;
        await _upsertQuest(
          goalId: goalId,
          uid: uid,
          category: cat,
          type: 'daily',
          avgAmount: avg,
        );
      }
    }

    // ── limit quest (เดิม) ─────────────────────────────────────────────────
    if (durationDays >= 30) {
      for (var cat in spendingLimitCategories) {
        final entries = grouped[cat] ?? [];
        if (entries.length >= kLimitTriggerCount) {
          final targetCount = (entries.length / 2).floor();
          final avg = entries.reduce((a, b) => a + b) ~/ entries.length;
          await _upsertQuest(
            goalId: goalId,
            uid: uid,
            category: cat,
            type: 'limit',
            avgAmount: avg,
            currentCount: entries.length,
            targetCount: targetCount,
          );
        }
      }
    }

    // ── self_compare quest (ใหม่) ──────────────────────────────────────────
    for (var cat in selfCompareCategories) {
      final entries = grouped[cat] ?? [];
      if (entries.length >= kSelfCompareTriggerCount) {
        final avg = entries.reduce((a, b) => a + b) ~/ entries.length;
        // คำนวณยอดเฉลี่ยต่อเดือนจาก 60 วัน
        final monthlyAvg = (avg * entries.length / 2).toInt();
        await _upsertSelfCompareQuest(
          goalId: goalId,
          uid: uid,
          category: cat,
          monthlyAvg: monthlyAvg,
        );
      }
    }

    // ── habit quest (ใหม่) — สร้าง 1 ต่อ goal เสมอ ─────────────────────────
    await _upsertHabitQuest(goalId: goalId, uid: uid);
  }

  // ─── upsert self_compare quest ───────────────────────────────────────────
  static Future<void> _upsertSelfCompareQuest({
    required String goalId,
    required String uid,
    required String category,
    required int monthlyAvg,
  }) async {
    final existing = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('category', isEqualTo: category)
        .where('type', isEqualTo: 'self_compare')
        .get();

    final notCancelled =
        existing.docs.where((d) => d['status'] != 'cancelled').toList();
    if (notCancelled.isNotEmpty) return;

    await _db.collection('quests').add({
      'userID': uid,
      'goalId': goalId,
      'category': category,
      'type': 'self_compare',
      'monthlyAvg': monthlyAvg,
      // เป้าหมาย: ใช้น้อยกว่าค่าเฉลี่ย 10%
      'targetAmount': (monthlyAvg * 0.9).toInt(),
      'status': 'inactive',
      'totalSaved': 0,
      'successCount': 0, // จำนวนเดือนที่ทำสำเร็จ
      'createdAt': Timestamp.now(),
    });
  }

  // ─── upsert habit quest ───────────────────────────────────────────────────
  static Future<void> _upsertHabitQuest({
    required String goalId,
    required String uid,
  }) async {
    final existing = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('type', isEqualTo: 'habit')
        .get();

    final notCancelled =
        existing.docs.where((d) => d['status'] != 'cancelled').toList();
    if (notCancelled.isNotEmpty) return;

    await _db.collection('quests').add({
      'userID': uid,
      'goalId': goalId,
      'category': 'บันทึกรายจ่าย',
      'type': 'habit',
      'targetDays': 7,
      'status': 'active', // เปิดอัตโนมัติเสมอ ไม่ต้อง toggle
      'currentStreak': 0,
      'longestStreak': 0,
      'completedCount': 0,
      'createdAt': Timestamp.now(),
    });
  }

  // ─── สร้างหรืออัปเดต quest (เดิม) ──────────────────────────────────────
  static Future<void> _upsertQuest({
    required String goalId,
    required String uid,
    required String category,
    required String type,
    required int avgAmount,
    int? currentCount,
    int? targetCount,
  }) async {
    final existing = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('category', isEqualTo: category)
        .get();

    final notCancelled =
        existing.docs.where((d) => d['status'] != 'cancelled').toList();
    if (notCancelled.isNotEmpty) return;

    await _db.collection('quests').add({
      'userID': uid,
      'goalId': goalId,
      'category': category,
      'type': type,
      'avgAmount': avgAmount,
      'status': 'inactive',
      'totalSaved': 0,
      'checkInCount': 0,
      if (currentCount != null) 'currentCount': currentCount,
      if (targetCount != null) 'targetCount': targetCount,
      'createdAt': Timestamp.now(),
    });
  }

  // ─── เปิด/ปิด quest ──────────────────────────────────────────────────────
  static Future<void> toggleQuest(String questId, bool active) async {
    await _db.collection('quests').doc(questId).update({
      'status': active ? 'active' : 'inactive',
    });
  }

  // ─── Check-in Daily Quest (เดิม) ─────────────────────────────────────────
  static Future<CheckInResult> checkInDaily(
      String questId, int avgAmount, String goalId) async {
    final today = _dateKey(DateTime.now());

    final progressRef = _db.collection('questProgress').doc(questId);
    final progressSnap = await progressRef.get();

    List<String> checkedDates = [];
    if (progressSnap.exists) {
      checkedDates =
          List<String>.from(progressSnap.data()!['checkedInDates'] ?? []);
    }

    if (checkedDates.contains(today)) return CheckInResult.alreadyChecked;

    checkedDates.add(today);

    await progressRef.set({
      'questId': questId,
      'goalId': goalId,
      'checkedInDates': checkedDates,
    }, SetOptions(merge: true));

    await _db.collection('quests').doc(questId).update({
      'checkInCount': FieldValue.increment(1),
      'totalSaved': FieldValue.increment(avgAmount),
    });

    await _addSavingToGoal(goalId, avgAmount, source: 'daily_quest');

    return CheckInResult.success;
  }

  // ─── Check Habit Quest (ใหม่) ─────────────────────────────────────────────
  // เรียกทุกครั้งที่มีการบันทึก transaction ใหม่
  static Future<void> checkHabitQuests(String goalId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

    final snap = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('type', isEqualTo: 'habit')
        .get();

    for (var doc in snap.docs) {
      final data = doc.data();
      final targetDays = data['targetDays'] as int;

      final progressRef = _db.collection('questProgress').doc(doc.id);
      final progressSnap = await progressRef.get();

      List<String> recordedDates = [];
      if (progressSnap.exists) {
        recordedDates =
            List<String>.from(progressSnap.data()!['recordedDates'] ?? []);
      }

      // ถ้าวันนี้ยังไม่ได้บันทึก → เพิ่ม
      if (!recordedDates.contains(today)) {
        recordedDates.add(today);
        await progressRef.set({
          'questId': doc.id,
          'goalId': goalId,
          'recordedDates': recordedDates,
        }, SetOptions(merge: true));
      } else {
        // บันทึกวันนี้ไปแล้ว ไม่ต้องทำอะไร
        continue;
      }

      // คำนวณ streak ปัจจุบัน
      int streak = _calculateStreak(recordedDates);

      // อัปเดต streak
      final currentLongest = (data['longestStreak'] as num?)?.toInt() ?? 0;
      await doc.reference.update({
        'currentStreak': streak,
        'longestStreak': streak > currentLongest ? streak : currentLongest,
      });

      // ถ้าครบ targetDays → reset streak เริ่มรอบใหม่
      if (streak >= targetDays) {
        await doc.reference.update({
          'completedCount': FieldValue.increment(1),
          'currentStreak': 0,
        });

        // reset recorded dates สำหรับรอบใหม่
        await progressRef.set({
          'questId': doc.id,
          'goalId': goalId,
          'recordedDates': [],
        }, SetOptions(merge: true));
      }
    }
  }

  // ─── Check Self Compare Quest สิ้นเดือน (ใหม่) ──────────────────────────
  static Future<void> checkMonthlySelfCompareQuests(String goalId) async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final snap = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('type', isEqualTo: 'self_compare')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in snap.docs) {
      final data = doc.data();
      final category = data['category'] as String;
      final targetAmount = data['targetAmount'] as int;
      final monthlyAvg = data['monthlyAvg'] as int;

      // ดึง transaction เดือนนี้ของหมวดนี้
      final txSnap = await _db
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final actualAmount = txSnap.docs
          .fold<int>(0, (sum, d) => sum + (d['amount'] as num).toInt());

      if (actualAmount <= targetAmount) {
        // สำเร็จ! คำนวณเงินที่ประหยัดได้
        final savedAmount = monthlyAvg - actualAmount;

        await doc.reference.update({
          'totalSaved': FieldValue.increment(savedAmount),
          'successCount': FieldValue.increment(1),
          'lastMonthResult': {
            'monthYear': monthYear,
            'actualAmount': actualAmount,
            'targetAmount': targetAmount,
            'savedAmount': savedAmount,
            'success': true,
          },
        });

        await _addSavingToGoal(goalId, savedAmount,
            source: 'self_compare_quest');
      } else {
        await doc.reference.update({
          'lastMonthResult': {
            'monthYear': monthYear,
            'actualAmount': actualAmount,
            'targetAmount': targetAmount,
            'savedAmount': 0,
            'success': false,
          },
        });
      }
    }
  }

  // ─── Check-in Spending Limit สิ้นเดือน (เดิม) ───────────────────────────
  static Future<void> checkMonthlyLimitQuests(String goalId) async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final startOfMonth = DateTime(now.year, now.month, 1);

    final snap = await _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('type', isEqualTo: 'limit')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in snap.docs) {
      final data = doc.data();
      final targetCount = data['targetCount'] as int;
      final avgAmount = data['avgAmount'] as int;
      final category = data['category'] as String;

      final txSnap = await _db
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('category', isEqualTo: category)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      final actualCount = txSnap.docs.length;

      if (actualCount <= targetCount) {
        final savedCount = (data['currentCount'] as int) - actualCount;
        final savedAmount = savedCount * avgAmount;

        await doc.reference.update({
          'totalSaved': FieldValue.increment(savedAmount),
          'lastMonthResult': {
            'monthYear': monthYear,
            'actualCount': actualCount,
            'savedAmount': savedAmount,
            'success': true,
          },
        });

        await _addSavingToGoal(goalId, savedAmount, source: 'limit_quest');
      } else {
        await doc.reference.update({
          'lastMonthResult': {
            'monthYear': monthYear,
            'actualCount': actualCount,
            'savedAmount': 0,
            'success': false,
          },
        });
      }
    }

    // เรียก self_compare ด้วยในวันเดียวกัน
    await checkMonthlySelfCompareQuests(goalId);
  }

  // ─── เพิ่มเงินเข้า goal + บันทึก log ────────────────────────────────────
  static Future<void> _addSavingToGoal(String goalId, int amount,
      {String? source}) async {
    if (amount <= 0) return;
    final goalRef = _db.collection('goals').doc(goalId);
    final batch = _db.batch();

    batch.update(goalRef, {
      'savedAmount': FieldValue.increment(amount),
    });

    batch.set(
      goalRef.collection('savingLogs').doc(),
      {
        'amount': amount,
        'source': source ?? 'quest',
        'createdAt': Timestamp.now(),
      },
    );

    await batch.commit();
  }

  // ─── คำนวณ streak จาก list ของ dateKey ───────────────────────────────────
  static int _calculateStreak(List<String> dates) {
    if (dates.isEmpty) return 0;
    final sorted = [...dates]..sort();
    int streak = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      final current = DateTime.parse(sorted[i]);
      final prev = DateTime.parse(sorted[i - 1]);
      final diff = current.difference(prev).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── Streams ─────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> allQuestsStream(String goalId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('quests')
        .where('userID', isEqualTo: uid)
        .where('goalId', isEqualTo: goalId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Stream<QuerySnapshot> activeQuestsStream(String goalId) {
    return _db
        .collection('quests')
        .where('goalId', isEqualTo: goalId)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  static Stream<DocumentSnapshot> progressStream(String questId) {
    return _db.collection('questProgress').doc(questId).snapshots();
  }

  // ─── helper ──────────────────────────────────────────────────────────────
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

enum CheckInResult { success, alreadyChecked, error }