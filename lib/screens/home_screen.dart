import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'alert_screen.dart';
import 'assistant_bot.dart';
import 'map_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // default to Weather tab

  static const Color typhoonBlue = Color(0xFF1565C0); // Deep blue
  static const Color lightBlue = Color(0xFFF1F8FF); // Very light blue

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MapScreen(apiKey: 'AIzaSyDTmj0gH25EYsI7efyTGUpRuGUR0mqhtvg'),
      AssistantBotScreen(apiKey: 'AIzaSyBtqDvSymP8jv3cg0dbubVENiXhoLKRoGs'),
      WeatherScreen(),
      AlertScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        backgroundColor: typhoonBlue,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.3),
        centerTitle: true,
        title: Text(
          "🌀 TyphoonGuard",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: typhoonBlue,
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map), label: "Evac Map"),
              BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy),
                label: "Assistant",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud),
                label: "Weather",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.warning),
                label: "Track",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
