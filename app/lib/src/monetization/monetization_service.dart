import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../config/app_config.dart";
import "../models/monetization.dart";

class MonetizationService {
  MonetizationService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: "us-central1",
  );
  static const Duration _defaultStatusCacheMaxAge = Duration(minutes: 2);
  static MonetizationStatus? _cachedStatus;
  static DateTime? _cachedStatusAt;
  static String? _cachedStatusUid;
  static Future<MonetizationStatus>? _inflightStatusRequest;

  static void _invalidateCacheIfUserChanged() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_cachedStatusUid != currentUid) {
      _cachedStatus = null;
      _cachedStatusAt = null;
      _cachedStatusUid = currentUid;
    }
  }

  static MonetizationStatus? getCachedStatus({
    Duration maxAge = _defaultStatusCacheMaxAge,
  }) {
    _invalidateCacheIfUserChanged();
    final cached = _cachedStatus;
    final cachedAt = _cachedStatusAt;
    if (cached == null || cachedAt == null) {
      return null;
    }
    if (DateTime.now().difference(cachedAt) > maxAge) {
      return null;
    }
    return cached;
  }

  static Future<MonetizationStatus?> prefetchStatus({
    bool forceRefresh = false,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _invalidateCacheIfUserChanged();
      return null;
    }
    try {
      return await getStatus(forceRefresh: forceRefresh);
    } catch (_) {
      return null;
    }
  }

  static Future<MonetizationStatus> getStatus({
    bool forceRefresh = false,
  }) async {
    _invalidateCacheIfUserChanged();
    if (!forceRefresh) {
      final cached = getCachedStatus();
      if (cached != null) {
        return cached;
      }
      final inFlight = _inflightStatusRequest;
      if (inFlight != null) {
        return inFlight;
      }
    }

    final request = (() async {
      final parsed = await _fetchStatusFromNetwork();
      _cachedStatus = parsed;
      _cachedStatusAt = DateTime.now();
      _cachedStatusUid = FirebaseAuth.instance.currentUser?.uid;
      return parsed;
    })();
    _inflightStatusRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_inflightStatusRequest, request)) {
        _inflightStatusRequest = null;
      }
    }
  }

  static void clearStatusCache() {
    _cachedStatus = null;
    _cachedStatusAt = null;
    _cachedStatusUid = FirebaseAuth.instance.currentUser?.uid;
    _inflightStatusRequest = null;
  }

  static Future<MonetizationStatus> refreshStatus() async {
    return getStatus(forceRefresh: true);
  }

  static Future<MonetizationStatus> _fetchStatusFromNetwork() async {
    final callable = _functions.httpsCallable("getMonetizationStatus");
    final result = await callable.call(<String, dynamic>{});
    final data = result.data;
    if (data is! Map) {
      throw const FormatException("Unexpected getMonetizationStatus response");
    }
    return MonetizationStatus.fromMap(Map<String, dynamic>.from(data));
  }

  static Uri _baseReturnUri() {
    if (kIsWeb) {
      final base = Uri.base;
      final origin = base.origin;
      return Uri.parse(origin);
    }
    return Uri.parse("reloved://support");
  }

  static ({String successUrl, String cancelUrl}) _buildReturnUrls(
    PaywallContext source,
  ) {
    final sourceParam = paywallContextToWire(source);
    final baseUri = _baseReturnUri();
    if (kIsWeb) {
      final successUrl = baseUri.replace(
        path: "/",
        queryParameters: {"support_checkout": "success", "source": sourceParam},
      );
      final cancelUrl = baseUri.replace(
        path: "/",
        queryParameters: {"support_checkout": "cancel", "source": sourceParam},
      );
      return (
        successUrl: successUrl.toString(),
        cancelUrl: cancelUrl.toString(),
      );
    }

    final successUrl = baseUri.replace(
      path: "/success",
      queryParameters: {"source": sourceParam},
    );
    final cancelUrl = baseUri.replace(
      path: "/cancel",
      queryParameters: {"source": sourceParam},
    );
    return (successUrl: successUrl.toString(), cancelUrl: cancelUrl.toString());
  }

  static bool get checkoutSupportedByPlatform =>
      AppConfig.paymentsEnabledForCurrentPlatform;

  static bool isCheckoutEnabled(MonetizationStatus? status) {
    if (!checkoutSupportedByPlatform) {
      return false;
    }
    if (status == null) {
      return true;
    }
    return status.features.monetizationEnabled &&
        status.features.checkoutEnabled;
  }

  static Future<bool> openSupportCheckout({
    required SupportPlanType planType,
    required PaywallContext source,
    MonetizationStatus? status,
  }) async {
    if (!isCheckoutEnabled(status)) {
      return false;
    }
    final urls = _buildReturnUrls(source);
    final callable = _functions.httpsCallable("createSupportCheckoutSession");
    final result = await callable.call(<String, dynamic>{
      "planType": supportPlanTypeToWire(planType),
      "source": paywallContextToWire(source),
      "successUrl": urls.successUrl,
      "cancelUrl": urls.cancelUrl,
    });
    final data = result.data;
    if (data is! Map) {
      throw const FormatException(
        "Unexpected createSupportCheckoutSession response",
      );
    }
    final checkoutUrl = data["url"];
    if (checkoutUrl is! String || checkoutUrl.isEmpty) {
      throw const FormatException("Missing checkout URL");
    }
    final uri = Uri.parse(checkoutUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openBillingPortal() async {
    if (!checkoutSupportedByPlatform) {
      return false;
    }
    final returnUrl = _baseReturnUri().toString();
    final callable = _functions.httpsCallable("createBillingPortalSession");
    final result = await callable.call(<String, dynamic>{
      "returnUrl": returnUrl,
    });
    final data = result.data;
    if (data is! Map) {
      throw const FormatException(
        "Unexpected createBillingPortalSession response",
      );
    }
    final portalUrl = data["url"];
    if (portalUrl is! String || portalUrl.isEmpty) {
      throw const FormatException("Missing billing portal URL");
    }
    final uri = Uri.parse(portalUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

enum SoftPaywallDecision { continueFree, openedCheckout, dismissed }

Future<SoftPaywallDecision> showSoftPaywallSheet({
  required BuildContext context,
  required PaywallContext paywallContext,
  required MonetizationStatus status,
}) async {
  final decision = await showModalBottomSheet<SoftPaywallDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _SoftPaywallSheetContent(
      paywallContext: paywallContext,
      status: status,
    ),
  );
  return decision ?? SoftPaywallDecision.dismissed;
}

class _SoftPaywallSheetContent extends StatefulWidget {
  const _SoftPaywallSheetContent({
    required this.paywallContext,
    required this.status,
  });

  final PaywallContext paywallContext;
  final MonetizationStatus status;

  @override
  State<_SoftPaywallSheetContent> createState() =>
      _SoftPaywallSheetContentState();
}

class _SoftPaywallSheetContentState extends State<_SoftPaywallSheetContent> {
  bool _isBusy = false;
  String? _error;

  String _titleForContext(PaywallContext context) {
    switch (context) {
      case PaywallContext.publish:
        return "Thanks for being an active member";
      case PaywallContext.contact:
        return "You are very active in contacts";
      case PaywallContext.aboutSupport:
        return "Support ReLoved";
    }
  }

  String _messageForContext(PaywallContext context) {
    switch (context) {
      case PaywallContext.publish:
        return "You reached the free limit for active items. "
            "Support is optional and you can continue for free.";
      case PaywallContext.contact:
        return "You reached the free limit for new item contacts this week. "
            "Support is optional and you can continue for free.";
      case PaywallContext.aboutSupport:
        return "ReLoved is community-powered. Support is optional and helps keep "
            "the app running.";
    }
  }

  Future<void> _startCheckout(SupportPlanType planType) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final opened = await MonetizationService.openSupportCheckout(
        planType: planType,
        source: widget.paywallContext,
        status: widget.status,
      );
      if (!mounted) {
        return;
      }
      if (!opened) {
        setState(() {
          _error = "Could not open checkout.";
          _isBusy = false;
        });
        return;
      }
      Navigator.of(context).pop(SoftPaywallDecision.openedCheckout);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = "Checkout is temporarily unavailable.";
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canCheckout = MonetizationService.isCheckoutEnabled(widget.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _titleForContext(widget.paywallContext),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _messageForContext(widget.paywallContext),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "Paying is optional. You can always continue without paying.",
            style: textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isBusy || !canCheckout
                ? null
                : () => _startCheckout(SupportPlanType.oneOffDonation),
            child: const Text("Donate £3"),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isBusy || !canCheckout
                ? null
                : () => _startCheckout(SupportPlanType.monthlySubscription),
            child: const Text("Subscribe £4.99/month"),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(SoftPaywallDecision.continueFree),
            child: const Text("Continue without paying"),
          ),
        ],
      ),
    );
  }
}
