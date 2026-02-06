import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../auth/auth_screen.dart";
import "profile_screen.dart";
import "publish_screen.dart";
import "search_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data != null;
        final pages = isSignedIn
            ? const [SearchScreen(), PublishScreen(), ProfileScreen()]
            : const [SearchScreen(), AuthScreen()];
        final items = isSignedIn
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Search",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: "Publish",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: "Profile",
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Search",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.login),
                  label: "Sign in",
                ),
              ];
        final effectiveIndex =
            _currentIndex < pages.length ? _currentIndex : 0;
        if (effectiveIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex = effectiveIndex;
              });
            }
          });
        }
        return Scaffold(
          body: IndexedStack(
            index: effectiveIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: effectiveIndex,
            onTap: (value) {
              setState(() {
                _currentIndex = value;
              });
            },
            items: items,
          ),
        );
      },
    );
  }
}
