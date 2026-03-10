import 'package:flutter/material.dart';
import 'dialer_screen.dart';
import 'call_history_screen.dart';
import 'contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DialerScreen(),
    const CallHistoryScreen(),
    const ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dialpad),
            label: '拨号',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: '通话记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts),
            label: '通讯录',
          ),
        ],
      ),
    );
  }
}
