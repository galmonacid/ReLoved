import "package:flutter/material.dart";

import "../analytics/app_analytics.dart";
import "../models/monetization.dart";
import "../monetization/monetization_service.dart";

class AboutSupportScreen extends StatefulWidget {
  const AboutSupportScreen({super.key});

  @override
  State<AboutSupportScreen> createState() => _AboutSupportScreenState();
}

class _AboutSupportScreenState extends State<AboutSupportScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  MonetizationStatus? _status;

  @override
  void initState() {
    super.initState();
    AppAnalytics.logEvent(name: "about_support_opened");
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final status = await MonetizationService.getStatus();
      if (!mounted) {
        return;
      }
      await AppAnalytics.logEvent(
        name: "monetization_flag_state",
        parameters: status.features.analyticsParams(
          source: paywallContextToWire(PaywallContext.aboutSupport),
        ),
      );
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = "Could not load support status.";
      });
    }
  }

  Future<void> _openCheckout(SupportPlanType planType) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await AppAnalytics.logEvent(
        name: "support_checkout_started",
        parameters: {"planType": supportPlanTypeToWire(planType)},
      );
      final opened = await MonetizationService.openSupportCheckout(
        planType: planType,
        source: PaywallContext.aboutSupport,
        status: _status,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open checkout.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Checkout is temporarily unavailable.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openBillingPortal() async {
    if (!MonetizationService.isCheckoutEnabled(_status)) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      final opened = await MonetizationService.openBillingPortal();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open billing portal.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Billing portal is temporarily unavailable."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _membershipLabel(MonetizationStatus? status) {
    if (status == null) {
      return "Free member";
    }
    if (status.isMonthlySupporter) {
      return "Supporter monthly member";
    }
    return "Free member";
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final supportUiEnabled = status?.supportUiEnabled ?? false;
    final paymentsEnabled = MonetizationService.isCheckoutEnabled(status);
    return Scaffold(
      appBar: AppBar(title: const Text("About & Support")),
      body: RefreshIndicator(
        onRefresh: _refreshStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "ReLoved helps people give and find useful items locally.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Your optional support helps us keep hosting, moderation, and "
              "maintenance running for the community.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              "Paying is optional. You can continue using the app for free.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_error != null && !_isLoading)
              Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            if (!_isLoading && !supportUiEnabled) ...[
              Text(
                "Support is currently unavailable.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (!_isLoading && supportUiEnabled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Current membership",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _membershipLabel(_status),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (!paymentsEnabled) ...[
                Text(
                  "Support checkout is currently unavailable on this platform.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isBusy || !paymentsEnabled
                    ? null
                    : () => _openCheckout(SupportPlanType.oneOffDonation),
                child: const Text("Donate £3"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isBusy || !paymentsEnabled
                    ? null
                    : () => _openCheckout(SupportPlanType.monthlySubscription),
                child: const Text("Subscribe £4.99/month"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isBusy || !paymentsEnabled
                    ? null
                    : _openBillingPortal,
                child: const Text("Manage subscription"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
