import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:giziku/screens/onboarding_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
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
                  color: const Color(
                    0xFF2ECC71,
                  ),
                  fontSize: 32,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
