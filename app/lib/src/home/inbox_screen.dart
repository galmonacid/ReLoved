import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../../theme/app_colors.dart";
import "../chat/chat_service.dart";
import "../models/conversation.dart";
import "../widgets/item_image.dart";
import "../widgets/motion/pressable_scale.dart";
import "chat_thread_screen.dart";

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) {
      return "";
    }
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final difference = now.difference(local);
    if (difference.inMinutes < 1) {
      return "now";
    }
    if (difference.inHours < 1) {
      return "${difference.inMinutes}m";
    }
    if (difference.inDays < 1) {
      return "${difference.inHours}h";
    }
    return "${local.day}/${local.month}";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Sign in to access your inbox.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Inbox")),
      body: StreamBuilder<List<Conversation>>(
        stream: ChatService.streamUserConversations(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load conversations."));
          }

          final conversations = snapshot.data ?? const <Conversation>[];
          if (conversations.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final unread = conversation.unreadForUser(user.uid);
              final lastPreview = (conversation.lastMessagePreview ?? "")
                  .trim();
              final preview = lastPreview.isEmpty
                  ? "No messages yet"
                  : lastPreview;
              final trailingText = _formatTimestamp(conversation.lastMessageAt);

              return PressableScale(
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatThreadScreen(conversationId: conversation.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ItemImage(
                              photoUrl: conversation.itemPhotoUrl,
                              photoPath: "",
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  "Photo for ${conversation.itemTitle}",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.itemTitle.isEmpty
                                      ? "Item conversation"
                                      : conversation.itemTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  conversation.itemApproxArea,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (trailingText.isNotEmpty)
                                Text(
                                  trailingText,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              const SizedBox(height: 8),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? "99+" : "$unread",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                            ],
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
    );
  }
}
