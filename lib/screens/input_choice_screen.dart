import 'package:flutter/material.dart';
import 'package:giziku/screens/scan_food_screen.dart';
import 'package:giziku/screens/manual_input_screen.dart';

class InputChoiceScreen extends StatefulWidget {
  const InputChoiceScreen({super.key});

  @override
  State<InputChoiceScreen> createState() => _InputChoiceScreenState();
}

class _InputChoiceScreenState extends State<InputChoiceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Gizi',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: 'ku',
                    style: TextStyle(
                      color: const Color(0xFF2ECC45),
                      fontSize: 32,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            _buildMenuButton(
              title: 'Scan',
              subtitle: 'Untuk hasil perhitungan yang cepat',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScanFoodScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            _buildMenuButton(
              title: 'Manual',
              subtitle: 'Untuk hasil perhitungan yang akurat',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualInputScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC45),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
