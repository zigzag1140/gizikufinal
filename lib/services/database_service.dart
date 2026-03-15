import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; 

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- BAGIAN PROFIL USER (SETUP) ---

  Future<bool> checkUserDataExists(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      return doc.exists &&
          (doc.data() as Map<String, dynamic>).containsKey('goal');
    } catch (e) {
      print("Error checking user data: $e");
      return false;
    }
  }

  Future<void> saveUserGoal(String uid, String goal) async {
    try {
      await _db.collection('users').doc(uid).set({
        'goal': goal,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving goal: $e");
      rethrow;
    }
  }

  Future<void> saveUserGender(String uid, String gender) async {
    try {
      await _db.collection('users').doc(uid).set({
        'gender': gender,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving gender: $e");
      rethrow;
    }
  }

  Future<void> saveUserHeight(String uid, int height) async {
    try {
      await _db.collection('users').doc(uid).set({
        'height': height,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving height: $e");
      rethrow;
    }
  }

  Future<void> saveUserWeight(String uid, int weight) async {
    try {
      await _db.collection('users').doc(uid).set({
        'weight': weight,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving weight: $e");
      rethrow;
    }
  }

  Future<void> saveUserName(String uid, String name) async {
    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
        'profile_completed': true,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving name: $e");
      rethrow;
    }
  }

  Future<void> finalizeProfile(String uid, String name) async {
    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
      }, SetOptions(merge: true));

      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        int weight = data['weight'] ?? 0;
        int height = data['height'] ?? 0;
        int age = data['age'] ?? 0;
        String gender = data['gender'] ?? 'Laki-Laki';
        String goal = data['goal'] ?? 'Jaga BB';

        // Perhitungan BMR & TDEE
        double bmr;
        if (gender == 'Laki-Laki') {
          bmr = (10.0 * weight) + (6.25 * height) - (5.0 * age) + 5;
        } else {
          bmr = (10.0 * weight) + (6.25 * height) - (5.0 * age) - 161;
        }

        double tdee = bmr * 1.375;

        double finalCalories = tdee;
        if (goal == 'Turunkan BB') {
          finalCalories = tdee - 500;
        } else if (goal == 'Naikkan BB') {
          finalCalories = tdee + 500;
        }

        await _db.collection('users').doc(uid).set({
          'daily_calorie_target': finalCalories.round(),
          'profile_completed': true, 
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error finalizing profile: $e");
      rethrow;
    }
  }

  Future<bool> checkIfProfileComplete(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Cek 1: Apakah ada flag 'profile_completed'?
        bool hasFlag = data['profile_completed'] == true;

        // Cek 2: Apakah user SUDAH punya target kalori?
        bool hasTarget =
            data.containsKey('daily_calorie_target') &&
            data['daily_calorie_target'] != null;

        // Jika salah satu benar, maka anggap profil LENGKAP
        return hasFlag || hasTarget;
      }
      return false;
    } catch (e) {
      print("Error checking profile: $e");
      return false;
    }
  }

  Future<int> getDailyCalorieTarget(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['daily_calorie_target'] ?? 2000;
      }
      return 2000;
    } catch (e) {
      print("Error getting calorie target: $e");
      return 2000;
    }
  }

  Future<void> saveUserDob(String uid, DateTime selectedDate, int age) async {
    try {
      await _db.collection('users').doc(uid).set({
        'dob': selectedDate,
        'age': age,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving DOB: $e");
    }
  }

  // --- HELPER DATE FORMATTER ---
  String _formatDate(DateTime date) {
    String year = date.year.toString();
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  // --- KALORI HARIAN ---

  Future<Map<String, int>> getCalorieData(String uid, DateTime date) async {
    try {
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      int target = 2000;
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        target = data['daily_calorie_target'] ?? 2000;
      }

      String dateString = _formatDate(date);

      QuerySnapshot logSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .where('date_string', isEqualTo: dateString)
          .get();

      int totalConsumed = 0;
      for (var doc in logSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int cal = (data['calories'] as num).toInt();
        totalConsumed += cal;
      }

      return {'target': target, 'consumed': totalConsumed};
    } catch (e) {
      print("Error getting calorie data: $e");
      return {'target': 2000, 'consumed': 0};
    }
  }

  Future<void> logFoodItem(String uid, String foodName, int calories) async {
    try {
      DateTime now = DateTime.now();
      String dateString = _formatDate(now);

      await _db.collection('users').doc(uid).collection('food_logs').add({
        'food_name': foodName,
        'calories': calories,
        'timestamp': FieldValue.serverTimestamp(),
        'date_string': dateString,
      });
    } catch (e) {
      print("Error logging food: $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot> getDailyFoodLog(String uid, DateTime date) {
    String dateString = _formatDate(date);
    return _db
        .collection('users')
        .doc(uid)
        .collection('food_logs')
        .where('date_string', isEqualTo: dateString)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }


  // 1. Update Nama User
  Future<void> updateUserName(String uid, String newName) async {
    await _db.collection('users').doc(uid).update({'name': newName});
  }

  // 2. Update Foto Profil
  Future<void> updateUserPhoto(String uid, String photoUrl) async {
    await _db.collection('users').doc(uid).update({'photo_url': photoUrl});
  }

  // 3. Ambil Data Grafik Mingguan
  Future<List<FlSpot>> getWeeklyCalorieData(String uid) async {
    List<FlSpot> spots = [];
    DateTime now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      String dateString = _formatDate(date);

      QuerySnapshot snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .where('date_string', isEqualTo: dateString)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc['calories'] as num).toDouble();
      }
      spots.add(FlSpot((6 - i).toDouble(), total));
    }
    return spots;
  }
}
