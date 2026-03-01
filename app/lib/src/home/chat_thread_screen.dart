import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../../theme/app_colors.dart";
import "../analytics/app_analytics.dart";
import "../chat/chat_service.dart";
import "../models/chat_message.dart";
import "../models/conversation.dart";
import "../widgets/motion/pressable_scale.dart";

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    AppAnalytics.logEvent(
      name: "chat_open",
      parameters: {"conversationId": widget.conversationId},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    if (_isMarkingRead) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    _isMarkingRead = true;
    try {
      await ChatService.markConversationRead(widget.conversationId);
    } catch (_) {
      // Ignore intermittent failures.
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ChatService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _messageController.clear();
      await AppAnalytics.logEvent(
        name: "chat_message_send",
        parameters: {"conversationId": widget.conversationId},
      );
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(_firebaseErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _closeConversation() async {
    try {
      await ChatService.closeConversationByDonor(widget.conversationId);
      await AppAnalytics.logEvent(
        name: "chat_close",
        parameters: {"conversationId": widget.conversationId},
      );
    } catch (error) {
      _showError(_firebaseErrorMessage(error));
    }
  }

  Future<void> _reopenConversation() async {
    try {
      await ChatService.reopenConversationByDonor(widget.conversationId);
      await AppAnalytics.logEvent(
        name: "chat_reopen",
        parameters: {"conversationId": widget.conversationId},
      );
    } catch (error) {
      _showError(_firebaseErrorMessage(error));
    }
  }

  Future<void> _blockConversationParticipant(Conversation conversation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final blockedUserId = conversation.otherParticipantId(user.uid);

    try {
      await ChatService.blockConversationParticipant(
        conversationId: conversation.id,
        blockedUserId: blockedUserId,
      );
      await AppAnalytics.logEvent(
        name: "chat_block",
        parameters: {"conversationId": conversation.id},
      );
    } catch (error) {
      _showError(_firebaseErrorMessage(error));
    }
  }

  Future<void> _reportConversation(Conversation conversation) async {
    final reportInput = await _showReportDialog();
    if (reportInput == null) {
      return;
    }
    try {
      await ChatService.reportConversation(
        conversationId: conversation.id,
        reason: reportInput.reason,
        details: reportInput.details,
      );
      await AppAnalytics.logEvent(
        name: "chat_report",
        parameters: {
          "conversationId": conversation.id,
          "reason": reportInput.reason,
        },
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report submitted.")));
    } catch (error) {
      _showError(_firebaseErrorMessage(error));
    }
  }

  Future<_ReportInput?> _showReportDialog() async {
    String selectedReason = "spam";
    final detailsController = TextEditingController();
    try {
      return await showDialog<_ReportInput>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Report conversation"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        items: const [
                          DropdownMenuItem(value: "spam", child: Text("Spam")),
                          DropdownMenuItem(
                            value: "inappropriate",
                            child: Text("Inappropriate"),
                          ),
                          DropdownMenuItem(
                            value: "harassment",
                            child: Text("Harassment"),
                          ),
                          DropdownMenuItem(
                            value: "other",
                            child: Text("Other"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedReason = value;
                          });
                        },
                        decoration: const InputDecoration(labelText: "Reason"),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailsController,
                        maxLines: 4,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: "Details (optional)",
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _ReportInput(
                          reason: selectedReason,
                          details: detailsController.text.trim(),
                        ),
                      );
                    },
                    child: const Text("Submit"),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      detailsController.dispose();
    }
  }

  String _firebaseErrorMessage(Object error) {
    final asString = error.toString();
    if (asString.isEmpty) {
      return "Could not complete the action.";
    }
    return asString;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    switch (status) {
      case "closed_by_owner":
        return "Chat closed by donor";
      case "archived_item_unavailable":
        return "Item unavailable. Chat is archived";
      case "blocked":
        return "Chat blocked";
      default:
        return "";
    }
  }

  String _timeLabel(DateTime? time) {
    if (time == null) {
      return "";
    }
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, "0");
    final mm = local.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Sign in required.")));
    }

    return StreamBuilder<Conversation?>(
      stream: ChatService.streamConversation(widget.conversationId),
      builder: (context, conversationSnapshot) {
        if (conversationSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (conversationSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Could not load conversation.")),
          );
        }

        final conversation = conversationSnapshot.data;
        if (conversation == null) {
          return const Scaffold(
            body: Center(child: Text("Conversation not found.")),
          );
        }

        if (conversation.isParticipant(user.uid)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markRead();
          });
        }

        final isOwner = conversation.isOwner(user.uid);
        final isReadOnly = conversation.isReadOnly;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              conversation.itemTitle.isEmpty
                  ? "Item chat"
                  : conversation.itemTitle,
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case "close":
                      await _closeConversation();
                      return;
                    case "reopen":
                      await _reopenConversation();
                      return;
                    case "block":
                      await _blockConversationParticipant(conversation);
                      return;
                    case "report":
                      await _reportConversation(conversation);
                      return;
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  if (isOwner && conversation.status == "open") {
                    items.add(
                      const PopupMenuItem(
                        value: "close",
                        child: Text("Close chat"),
                      ),
                    );
                  }
                  if (isOwner && conversation.status == "closed_by_owner") {
                    items.add(
                      const PopupMenuItem(
                        value: "reopen",
                        child: Text("Reopen chat"),
                      ),
                    );
                  }
                  if (conversation.status == "open") {
                    items.add(
                      const PopupMenuItem(
                        value: "block",
                        child: Text("Block user"),
                      ),
                    );
                  }
                  items.add(
                    const PopupMenuItem(value: "report", child: Text("Report")),
                  );
                  return items;
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (isReadOnly)
                Container(
                  width: double.infinity,
                  color: AppColors.sageSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    _statusLabel(conversation.status),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.body),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: ChatService.streamMessages(conversation.id),
                  builder: (context, messageSnapshot) {
                    if (messageSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (messageSnapshot.hasError) {
                      return const Center(
                        child: Text("Could not load messages."),
                      );
                    }
                    final messages =
                        messageSnapshot.data ?? const <ChatMessage>[];
                    if (messages.isEmpty) {
                      return const Center(child: Text("No messages yet."));
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scrollController.hasClients) {
                        return;
                      }
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == user.uid;
                        final bubbleColor = isMine
                            ? AppColors.primary
                            : AppColors.sageSoft;
                        final textColor = isMine
                            ? Colors.white
                            : AppColors.text;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.text,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: textColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeLabel(message.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: isMine
                                              ? Colors.white70
                                              : AppColors.muted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !isReadOnly && !_isSending,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: "Write a message",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PressableScale(
                        child: ElevatedButton(
                          onPressed: isReadOnly || _isSending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(52, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportInput {
  const _ReportInput({required this.reason, required this.details});

  final String reason;
  final String details;
}
