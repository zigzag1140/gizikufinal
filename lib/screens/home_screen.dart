import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:giziku/services/database_service.dart';
import 'package:giziku/screens/input_choice_screen.dart';
import 'package:giziku/screens/alarm_screen.dart';
import 'package:giziku/screens/chatbot_screen.dart';
import 'package:giziku/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController
  _mainPageController; 

  @override
  void initState() {
    super.initState();
    _mainPageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _mainPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),

      body: PageView(
        controller: _mainPageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(), 
        children: const [
          HomeTabContent(), 
          AlarmScreen(), 
          InputChoiceScreen(), 
          ChatbotScreen(),
          ProfileScreen(), 
        ],
      ),

      // BOTTOM NAVIGATION BAR
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(width: 0.30, color: Colors.grey)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          selectedItemColor: Colors.black,
          unselectedItemColor: const Color(0xFFE0E0E0),
          currentIndex: _selectedIndex,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: _onItemTapped, 
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'Alarm',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Plus',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  // State Data
  int _calorieTarget = 0;
  int _caloriesConsumed = 0;
  bool _isLoading = true;

  // State Kalender
  late DateTime _selectedDate;
  late DateTime _anchorDate;
  late PageController
  _pageController; 
  final int _initialPage = 500;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _anchorDate;
    _pageController = PageController(initialPage: _initialPage);
    _loadUserData(_selectedDate);
  }

  Future<void> _loadUserData(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      Map<String, int> data = await DatabaseService().getCalorieData(uid, date);
      if (mounted) {
        setState(() {
          _calorieTarget = data['target']!;
          _caloriesConsumed = data['consumed']!;
          _isLoading = false;
        });
      }
    }
  }

  // --- FUNGSI UPDATE TOTAL HARIAN ---
  Future<void> _updateDailySummary(int difference) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String dateID = DateFormat('yyyy-MM-dd').format(_selectedDate);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('daily_nutrition')
        .doc(dateID)
        .update({'consumed': FieldValue.increment(difference)});

    if (mounted) {
      setState(() {
        _caloriesConsumed += difference;
      });
    }
  }

  // --- FUNGSI HAPUS ---
  Future<void> _deleteFood(DocumentReference ref, int calories) async {
    await ref.delete();
    await _updateDailySummary(-calories);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Data dihapus & Total Kalori diperbarui"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // --- DIALOG KONFIRMASI HAPUS ---
  void _showDeleteConfirmation(DocumentReference ref, int calories) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Hapus Item?"),
          content: const Text("Yakin ingin menghapus riwayat makanan ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteFood(ref, calories);
              },
              child: const Text(
                "Ya, Hapus",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- FUNGSI EDIT ---
  void _showEditDialog(
    DocumentReference ref,
    Map<String, dynamic> currentData,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentData['food_name'] ?? '',
    );
    int oldCalories = currentData['calories'] ?? 0;
    final TextEditingController calorieController = TextEditingController(
      text: oldCalories.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Edit Data Makanan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nama Makanan"),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: calorieController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Total Kalori (kkal)",
                  suffixText: "kkal",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC45),
              ),
              onPressed: () async {
                int? newCalories = int.tryParse(calorieController.text);

                if (nameController.text.isNotEmpty && newCalories != null) {
                  await ref.update({
                    'food_name': nameController.text,
                    'calories': newCalories,
                  });

                  int difference = newCalories - oldCalories;
                  await _updateDailySummary(difference);

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Data berhasil diperbarui")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data tidak valid")),
                  );
                }
              },
              child: const Text(
                "Simpan",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dayName = DateFormat('EEEE').format(_selectedDate);
    String dateString = DateFormat('d MMMM').format(_selectedDate);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // HEADER TANGGAL
                  Text(
                    dateString,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    dayName,
                    style: const TextStyle(
                      color: Color(0xFF2ECC45),
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // KALENDER MINGGUAN
                  SizedBox(
                    height: 85,
                    child: PageView.builder(
                      key: const PageStorageKey('calendar_page_view'),
                      controller: _pageController,
                      itemBuilder: (context, index) {
                        int weekOffset = index - _initialPage;
                        DateTime startOfAnchorWeek = _anchorDate.subtract(
                          Duration(days: _anchorDate.weekday % 7),
                        );
                        DateTime startOfVisibleWeek = startOfAnchorWeek.add(
                          Duration(days: weekOffset * 7),
                        );
                        return _buildWeeklyRow(startOfVisibleWeek);
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: 292,
                    height: 292,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/geprek.png'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // TOTAL KALORI
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$_caloriesConsumed',
                          style: const TextStyle(
                            color: Color(0xFF2ECC45),
                            fontSize: 32,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '/$_calorieTarget',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Total Kalori',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.80),
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // LIST RIWAYAT MAKAN
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Riwayat Makan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: DatabaseService().getDailyFoodLog(
                      FirebaseAuth.instance.currentUser!.uid,
                      _selectedDate,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: SizedBox.shrink(),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "Tidak ada catatan makan pada tanggal ini.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: 'Poppins',
                            ),
                          ),
                        );
                      }

                      var logs = snapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          var doc = logs[index];
                          var food = doc.data() as Map<String, dynamic>;
                          int calorieValue = food['calories'] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Slidable(
                                key: ValueKey(doc.id),
                                startActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.25,
                                  children: [
                                    SlidableAction(
                                      onPressed: (context) =>
                                          _showEditDialog(doc.reference, food),
                                      backgroundColor: const Color(0xFF2ECC45),
                                      foregroundColor: Colors.white,
                                      icon: Icons.edit,
                                      label: 'Edit',
                                    ),
                                  ],
                                ),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.25,
                                  children: [
                                    SlidableAction(
                                      onPressed: (context) =>
                                          _showDeleteConfirmation(
                                            doc.reference,
                                            calorieValue,
                                          ),
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete,
                                      label: 'Hapus',
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2ECC45,
                                          ).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.restaurant_menu,
                                          color: Color(0xFF2ECC45),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          food['food_name'] ?? 'Makanan',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${food['calories']} kkal',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }

  // WIDGET BARIS MINGGUAN
  Widget _buildWeeklyRow(DateTime startOfWeek) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        DateTime date = startOfWeek.add(Duration(days: index));
        bool isSelected =
            date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        Color color = isSelected
            ? const Color(0xFF2ECC45)
            : const Color(0xFFE0E0E0);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              _isLoading = true;
            });
            _loadUserData(date);
          },
          child: Container(
            color: Colors.transparent,
            child: Column(
              children: [
                Text(
                  DateFormat('E').format(date).toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    color: isSelected ? Colors.black : const Color(0xFFE0E0E0),
                    fontSize: 32,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                FutureBuilder<Map<String, int>>(
                  future: DatabaseService().getCalorieData(
                    FirebaseAuth.instance.currentUser!.uid,
                    date,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Text(
                        '-',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 10,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    int dailyCal = snapshot.hasData
                        ? snapshot.data!['consumed'] ?? 0
                        : 0;
                    return Text(
                      dailyCal > 0 ? '$dailyCal' : '-',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
