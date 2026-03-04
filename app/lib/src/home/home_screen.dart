import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../auth/auth_screen.dart";
import "inbox_screen.dart";
import "profile_screen.dart";
import "publish_screen.dart";
import "search_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _guestIndex = 0;
  int _authIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data != null;
        final pages = isSignedIn
            ? const [
                SearchScreen(),
                InboxScreen(),
                PublishScreen(),
                ProfileScreen(),
              ]
            : const [SearchScreen(), AuthScreen()];
        final items = isSignedIn
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: "Search",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: "Inbox",
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
        final activeIndex = isSignedIn ? _authIndex : _guestIndex;
        final effectiveIndex = activeIndex < pages.length ? activeIndex : 0;
        if (effectiveIndex != activeIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                if (isSignedIn) {
                  _authIndex = effectiveIndex;
                } else {
                  _guestIndex = effectiveIndex;
                }
              });
            }
          });
        }
        return Scaffold(
          body: Stack(
            children: List.generate(pages.length, (index) {
              final active = index == effectiveIndex;
              return Positioned.fill(
                child: IgnorePointer(
                  ignoring: !active,
                  child: ExcludeSemantics(
                    excluding: !active,
                    child: AnimatedOpacity(
                      opacity: active ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: pages[index],
                    ),
                  ),
                ),
              );
            }),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: effectiveIndex,
            onTap: (value) {
              setState(() {
                if (isSignedIn) {
                  _authIndex = value;
                } else {
                  _guestIndex = value;
                }
              });
            },
            items: items,
          ),
        );
      },
    );
  }
}
