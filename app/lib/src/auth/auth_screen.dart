import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../analytics/app_analytics.dart";

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

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
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await AppAnalytics.logLogin();
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
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
      }
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? "Authentication error.");
    } catch (error) {
      _showError("Unexpected error.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await AppAnalytics.logEvent(
        name: "password_reset_request",
      );
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
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ReLoved"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                _isLogin ? "Sign in" : "Create account",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (!_isLogin)
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Display name",
                  ),
                ),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
