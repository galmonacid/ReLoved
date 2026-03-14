import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "../analytics/app_analytics.dart";
import "../testing/test_keys.dart";
import "../widgets/google_mark_icon.dart";
import "auth_service.dart";

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.authService,
    this.showAppleOverride,
    this.showGoogleOverride,
  });

  final AuthService? authService;
  final bool? showAppleOverride;
  final bool? showGoogleOverride;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  AuthService? _authService;

  bool _isLogin = true;
  bool _isEmailLoading = false;
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;

  bool get _isLoading => _isEmailLoading || _isAppleLoading || _isGoogleLoading;
  AuthService get _resolvedAuthService =>
      _authService ??= widget.authService ?? AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password are required.");
      return;
    }
    if (!_isLogin && displayName.isEmpty) {
      _showError("Display name is required.");
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await AppAnalytics.logLogin(loginMethod: "password");
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await credential.user?.updateDisplayName(displayName);
        await FirebaseFirestore.instance
            .collection("users")
            .doc(credential.user?.uid)
            .set({
              "displayName": displayName,
              "email": email,
              "createdAt": FieldValue.serverTimestamp(),
              "ratingAvg": 0,
              "ratingCount": 0,
            });
        await AppAnalytics.logSignUp(signUpMethod: "password");
        await AppAnalytics.logLogin(loginMethod: "password");
      }
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? "Authentication error.");
    } catch (_) {
      _showError("Unexpected error.");
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("Enter your email to reset your password.");
      return;
    }
    setState(() {
      _isEmailLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await AppAnalytics.logEvent(name: "password_reset_request");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Check your email to reset it.")),
      );
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? "Could not send the email.");
    } catch (_) {
      _showError("Could not send the email.");
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });
    try {
      final result = await _resolvedAuthService.signInWithGoogle(
        requestPasswordForLinking: _promptPasswordForLinking,
      );
      await _logSocialAuth(result);
      if (!mounted) return;
      if (result.didLinkProvider) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account linked successfully.")),
        );
      }
    } on AuthServiceException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError("Could not complete Google sign-in.");
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isAppleLoading = true;
    });
    try {
      final result = await _resolvedAuthService.signInWithApple(
        requestPasswordForLinking: _promptPasswordForLinking,
      );
      await _logSocialAuth(result);
      if (!mounted) {
        return;
      }
      if (result.didLinkProvider) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account linked successfully.")),
        );
      }
    } on AuthServiceException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError("Could not complete Apple sign-in.");
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  Future<void> _logSocialAuth(SocialSignInResult result) async {
    if (result.isNewUser) {
      await AppAnalytics.logSignUp(signUpMethod: result.loginMethod);
    }
    await AppAnalytics.logLogin(loginMethod: result.loginMethod);
  }

  Future<String?> _promptPasswordForLinking(
    String email,
    String providerLabel,
  ) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text("Link existing account"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$email is already registered with $providerLabel."),
                const SizedBox(height: 8),
                const Text("Enter your password to link both sign-in methods."),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                  autofocus: true,
                  onSubmitted: (_) =>
                      Navigator.of(context).pop(controller.text.trim()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text("Link account"),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showApple =
        widget.showAppleOverride ??
        isAppleSignInSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);
    final showGoogle =
        widget.showGoogleOverride ??
        isGoogleSignInSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);
    final showSocialSignIn = showApple || showGoogle;

    return Scaffold(
      appBar: AppBar(title: const Text("ReLoved")),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    Text(
                      _isLogin ? "Sign in" : "Create account",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    if (!_isLogin)
                      TextField(
                        key: const ValueKey(TestKeys.authDisplayNameField),
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: "Display name",
                        ),
                      ),
                    TextField(
                      key: const ValueKey(TestKeys.authEmailField),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    TextField(
                      key: const ValueKey(TestKeys.authPasswordField),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey(TestKeys.authSubmitButton),
                        onPressed: _isLoading ? null : _submit,
                        child: _isEmailLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isLogin ? "Sign in" : "Create account"),
                      ),
                    ),
                    if (_isLogin)
                      TextButton(
                        onPressed: _isLoading ? null : _sendPasswordReset,
                        child: const Text("Forgot your password?"),
                      ),
                    TextButton(
                      key: const ValueKey(TestKeys.authModeToggleButton),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Sign up"
                            : "Already have an account? Sign in",
                      ),
                    ),
                    if (showSocialSignIn) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "or continue with",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (showApple)
                        _SocialSignInButton(
                          key: const ValueKey(TestKeys.authAppleButton),
                          onPressed: _isLoading ? null : _signInWithApple,
                          icon: const Icon(Icons.apple),
                          label: "Continue with Apple",
                          isLoading: _isAppleLoading,
                        ),
                      if (showApple && showGoogle) const SizedBox(height: 12),
                      if (showGoogle)
                        _SocialSignInButton(
                          key: const ValueKey(TestKeys.authGoogleButton),
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: const GoogleMarkIcon(
                            key: ValueKey(TestKeys.authGoogleIcon),
                          ),
                          label: "Continue with Google",
                          isLoading: _isGoogleLoading,
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  const _SocialSignInButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isLoading,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isLoading ? 0 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: icon,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(label),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}
