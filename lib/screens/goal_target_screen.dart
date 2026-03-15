import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:giziku/services/database_service.dart';
import 'package:giziku/screens/gender_screen.dart'; 

class GoalTargetScreen extends StatefulWidget {
  const GoalTargetScreen({super.key});

  @override
  State<GoalTargetScreen> createState() => _GoalTargetScreenState();
}

class _GoalTargetScreenState extends State<GoalTargetScreen> {
  String? _selectedGoal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Target & Tujuan',
          style: TextStyle(
            color: Color(0xFF2ECC45),
            fontSize: 20,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Apa tujuan utamamu?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),

              _buildGoalCard('Turunkan BB'),
              const SizedBox(height: 20),

              _buildGoalCard('Jaga BB'),
              const SizedBox(height: 20),

              _buildGoalCard('Naikkan BB'),

              const Spacer(),

              ElevatedButton(
                onPressed: _selectedGoal == null
                    ? null
                    : () async {
                        print("Tujuan yang dipilih: $_selectedGoal");

                        String uid = FirebaseAuth.instance.currentUser!.uid;

                        await DatabaseService().saveUserGoal(
                          uid,
                          _selectedGoal!,
                        );

                        print("Data berhasil disimpan ke Firebase!");

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenderScreen(),
                            ),
                          );
                        }
                      },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((
                    Set<MaterialState> states,
                  ) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade400; 
                    }
                    return Colors.black; 
                  }),
                  minimumSize: MaterialStateProperty.all(
                    const Size(double.infinity, 64),
                  ),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                child: const Text(
                  'Next!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(String goalLabel) {
    bool isSelected = _selectedGoal == goalLabel;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goalLabel;
        });
      },
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ECC45) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (!isSelected) 
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: Text(
            goalLabel,
            style: TextStyle(
              color: isSelected ? const Color(0xFF2ECC45) : Colors.black,
              fontSize: 20,
              fontFamily: 'Poppins',
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
