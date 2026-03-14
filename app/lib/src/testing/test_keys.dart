class TestKeys {
  const TestKeys._();

  static const searchScreen = "search-screen";
  static const inboxScreen = "inbox-screen";
  static const itemDetailScreen = "item-detail-screen";
  static const chatThreadScreen = "chat-thread-screen";

  static const guestSignInTab = "guest-sign-in-tab";
  static const authEmailField = "auth-email-field";
  static const authPasswordField = "auth-password-field";
  static const authDisplayNameField = "auth-display-name-field";
  static const authSubmitButton = "auth-submit-button";
  static const authModeToggleButton = "auth-mode-toggle-button";

  static const navSearch = "nav-search";
  static const navInbox = "nav-inbox";
  static const navInboxUnreadBadge = "nav-inbox-unread-badge";
  static const navPublish = "nav-publish";
  static const navProfile = "nav-profile";

  static const searchKeywordField = "search-keyword-field";
  static const searchLocationChip = "search-location-chip";
  static const searchLocationState = "search-location-state";
  static const searchLocationAction = "search-location-action";
  static const searchLocationManualAction = "search-location-manual-action";
  static const searchKeywordEditable = "search-keyword-editable";
  static const publishLocationStatus = "publish-location-status";
  static const publishLocationAction = "publish-location-action";
  static const publishLocationTile = "publish-location-tile";
  static const itemOpenChatButton = "item-open-chat-button";
  static const itemOpenChatLoading = "item-open-chat-loading";
  static const chatMessageField = "chat-message-field";
  static const chatSendButton = "chat-send-button";
  static const chatMenuButton = "chat-menu-button";
  static const authAppleButton = "auth-apple-button";
  static const authGoogleButton = "auth-google-button";
  static const authGoogleIcon = "auth-google-icon";

  static String searchItemCard(String itemId) => "search-item-$itemId";
  static String inboxConversationTile(String conversationId) =>
      "inbox-conversation-$conversationId";
  static String inboxConversationUnreadBadge(String conversationId) =>
      "inbox-conversation-unread-$conversationId";
}
