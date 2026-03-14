import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../../theme/app_colors.dart";
import "../auth/auth_screen.dart";
import "../chat/chat_service.dart";
import "../testing/test_keys.dart";
import "inbox_screen.dart";
import "profile_screen.dart";
import "publish_screen.dart";
import "search_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.sessionOverride,
    this.signedInPagesOverride,
    this.guestPagesOverride,
    this.unreadBadgeCountStreamOverride,
  });

  final HomeScreenSessionOverride? sessionOverride;
  final List<Widget>? signedInPagesOverride;
  final List<Widget>? guestPagesOverride;
  final Stream<int>? unreadBadgeCountStreamOverride;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class HomeScreenSessionOverride {
  const HomeScreenSessionOverride({required this.isSignedIn, this.uid});

  final bool isSignedIn;
  final String? uid;
}

class _HomeScreenState extends State<HomeScreen> {
  int _guestIndex = 0;
  int _authIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sessionOverride = widget.sessionOverride;
    if (sessionOverride != null) {
      return _buildScaffold(
        isSignedIn: sessionOverride.isSignedIn,
        signedInUserId: sessionOverride.uid,
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return _buildScaffold(
          isSignedIn: snapshot.data != null,
          signedInUserId: snapshot.data?.uid,
        );
      },
    );
  }

  Widget _buildScaffold({
    required bool isSignedIn,
    required String? signedInUserId,
  }) {
    final pages = isSignedIn
        ? (widget.signedInPagesOverride ??
              const [
                SearchScreen(),
                InboxScreen(),
                PublishScreen(),
                ProfileScreen(),
              ])
        : (widget.guestPagesOverride ?? const [SearchScreen(), AuthScreen()]);
    final items = isSignedIn
        ? [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search, key: ValueKey(TestKeys.navSearch)),
              label: "Search",
            ),
            BottomNavigationBarItem(
              icon: _InboxNavIcon(
                uid: signedInUserId,
                unreadBadgeCountStreamOverride:
                    widget.unreadBadgeCountStreamOverride,
              ),
              label: "Inbox",
            ),
            const BottomNavigationBarItem(
              icon: Icon(
                Icons.add_circle_outline,
                key: ValueKey(TestKeys.navPublish),
              ),
              label: "Publish",
            ),
            const BottomNavigationBarItem(
              icon: Icon(
                Icons.person_outline,
                key: ValueKey(TestKeys.navProfile),
              ),
              label: "Profile",
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search, key: ValueKey(TestKeys.navSearch)),
              label: "Search",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.login, key: ValueKey(TestKeys.guestSignInTab)),
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
  }
}

class _InboxNavIcon extends StatelessWidget {
  const _InboxNavIcon({required this.uid, this.unreadBadgeCountStreamOverride});

  final String? uid;
  final Stream<int>? unreadBadgeCountStreamOverride;

  @override
  Widget build(BuildContext context) {
    final icon = const Icon(
      Icons.chat_bubble_outline,
      key: ValueKey(TestKeys.navInbox),
    );
    final effectiveUid = uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      return icon;
    }
    return StreamBuilder<int>(
      stream:
          unreadBadgeCountStreamOverride ??
          ChatService.streamUnreadInboxBadgeCount(effectiveUid),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        if (unreadCount <= 0) {
          return icon;
        }
        final badgeLabel = unreadCount > 99 ? "99+" : "$unreadCount";
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -10,
              top: -6,
              child: Container(
                key: const ValueKey(TestKeys.navInboxUnreadBadge),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
