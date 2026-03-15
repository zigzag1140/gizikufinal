import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:giziku/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color _gizikuGreen = const Color(0xFF2ECC45);

  // State Data User
  String _userName = "Memuat...";
  int _weight = 0;
  int _height = 0;
  bool _isLoading = true;

  // State Grafik (0 = Berat, 1 = Tinggi, 2 = BMI)
  int _selectedGraphIndex = 0;

  List<Map<String, dynamic>> _weightHistory = [];
  List<Map<String, dynamic>> _heightHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- 1. FETCH DATA ---
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Ambil Data Profil Utama (Nama, Berat Saat Ini, Tinggi Saat Ini)
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int currentWeight = data['weight'] ?? 0;
          int currentHeight = data['height'] ?? 0;

          // Ambil History Berat
          var weightQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('weight_logs')
              .orderBy('timestamp', descending: false)
              .limitToLast(7)
              .get();

          // Ambil History Tinggi
          var heightQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('height_logs')
              .orderBy('timestamp', descending: false)
              .limitToLast(7)
              .get();

          List<Map<String, dynamic>> wHistory = weightQuery.docs
              .map((e) => e.data())
              .toList();
          List<Map<String, dynamic>> hHistory = heightQuery.docs
              .map((e) => e.data())
              .toList();

          if (wHistory.isEmpty && currentWeight > 0) {
            wHistory.add({
              'weight': currentWeight,
              'date_str': 'Awal', 
            });
          }
          if (hHistory.isEmpty && currentHeight > 0) {
            hHistory.add({'height': currentHeight, 'date_str': 'Awal'});
          }

          if (mounted) {
            setState(() {
              _userName = data['name'] ?? 'User Giziku';
              _weight = currentWeight;
              _height = currentHeight;
              _weightHistory = wHistory;
              _heightHistory = hHistory;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- 2. UPDATE DATA ---
  Future<void> _updateUserData(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update data utama
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {field: value},
      );

      String collectionName = '';
      if (field == 'weight') collectionName = 'weight_logs';
      if (field == 'height') collectionName = 'height_logs';

      if (collectionName.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collectionName)
            .add({
              field: value,
              'timestamp': FieldValue.serverTimestamp(),
              'date_str': DateFormat('dd/MM').format(DateTime.now()),
            });
      }

      await _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Berhasil memperbarui $field!"),
            backgroundColor: _gizikuGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal update: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- DIALOGS ---
  void _showEditNameDialog() {
    TextEditingController controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Ganti Nama Panggilan",
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Nama baru",
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _gizikuGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                _updateUserData('name', controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _gizikuGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditNumberDialog(
    String title,
    String field,
    int currentValue,
    String unit,
  ) {
    TextEditingController controller = TextEditingController(
      text: currentValue.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Update $title",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _gizikuGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              int? newValue = int.tryParse(controller.text);
              if (newValue != null && newValue > 0) {
                _updateUserData(field, newValue);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _gizikuGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Konfirmasi Logout",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar?",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              "Logout",
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _gizikuGreen))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    _buildModernHeader(),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showEditNumberDialog(
                              "Berat Badan",
                              "weight",
                              _weight,
                              "kg",
                            ),
                            child: _buildStatCard(
                              title: "Berat Badan",
                              value: "$_weight",
                              unit: "kg",
                              icon: Icons.monitor_weight_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showEditNumberDialog(
                              "Tinggi Badan",
                              "height",
                              _height,
                              "cm",
                            ),
                            child: _buildStatCard(
                              title: "Tinggi Badan",
                              value: "$_height",
                              unit: "cm",
                              icon: Icons.height_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Statistik Tubuh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Colors.black87,
                          ),
                        ),
                        Icon(Icons.bar_chart_rounded, color: Colors.grey[400]),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildCapsuleToggle("Berat", 0)),
                          Expanded(child: _buildCapsuleToggle("Tinggi", 1)),
                          Expanded(child: _buildCapsuleToggle("BMI", 2)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildSelectedChart(),

                    const SizedBox(height: 40),

                    _buildLogoutButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET HELPER UTAMA ---

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _gizikuGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _gizikuGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Halo,",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _showEditNameDialog,
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: "Edit Nama",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gizikuGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _gizikuGreen, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleToggle(String label, int index) {
    bool isActive = _selectedGraphIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGraphIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _gizikuGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey[600],
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChart() {
    if (_selectedGraphIndex == 0) {
      return _buildChartCard(
        "Grafik Berat Badan",
        _weightHistory,
        "weight",
        _gizikuGreen,
        false,
      );
    } else if (_selectedGraphIndex == 1) {
      return _buildChartCard(
        "Grafik Tinggi Badan",
        _heightHistory,
        "height",
        Colors.blueAccent,
        false,
      );
    } else {
      return _buildBMIChartCard();
    }
  }

  Widget _buildChartCard(
    String title,
    List<Map<String, dynamic>> historyData,
    String dataKey,
    Color chartColor,
    bool isBMI,
  ) {
    if (historyData.isEmpty) {
      return _buildEmptyChart(dataKey);
    }

    List<FlSpot> spots = [];
    double minVal = 1000;
    double maxVal = 0;

    for (int i = 0; i < historyData.length; i++) {
      double val = (historyData[i][dataKey] as int).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }

    return _renderChart(
      spots,
      minVal - 5,
      maxVal + 5,
      historyData,
      chartColor,
      false,
    );
  }

  Widget _buildBMIChartCard() {
    if (_weightHistory.isEmpty || _height == 0) {
      return _buildEmptyChart("BMI");
    }

    List<FlSpot> spots = [];
    double minVal = 100;
    double maxVal = 0;
    double heightInM = _height / 100.0;

    for (int i = 0; i < _weightHistory.length; i++) {
      double weight = (_weightHistory[i]['weight'] as int).toDouble();
      double bmi = weight / (heightInM * heightInM);

      spots.add(FlSpot(i.toDouble(), bmi));
      if (bmi < minVal) minVal = bmi;
      if (bmi > maxVal) maxVal = bmi;
    }

    return _renderChart(
      spots,
      minVal - 2,
      maxVal + 2,
      _weightHistory,
      Colors.orange,
      true,
    );
  }

  Widget _buildEmptyChart(String label) {
    return Container(
      height: 250,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text(
            "Data $label belum tersedia",
            style: TextStyle(color: Colors.grey[500], fontFamily: 'Poppins'),
          ),
          Text(
            "Coba update data kamu di atas!",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderChart(
    List<FlSpot> spots,
    double minY,
    double maxY,
    List<Map<String, dynamic>> metaData,
    Color color,
    bool showIdealLines,
  ) {
    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey[100]!, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < metaData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        metaData[index]['date_str'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY < 0 ? 0 : minY,
          maxY: maxY,
          extraLinesData: showIdealLines
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 18.5,
                      color: Colors.green.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (line) => "Min Ideal",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    HorizontalLine(
                      y: 25.0,
                      color: Colors.green.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (line) => "Max Ideal",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                )
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[400]),
            const SizedBox(width: 10),
            Text(
              "Keluar Akun",
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
