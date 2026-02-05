import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter/material.dart";

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
      _showError("Email y password son obligatorios.");
      return;
    }
    if (!_isLogin && displayName.isEmpty) {
      _showError("El nombre visible es obligatorio.");
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
        await FirebaseAnalytics.instance.logLogin();
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
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: "password");
      }
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? "Error de autenticacion");
    } catch (error) {
      _showError("Error inesperado.");
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
      _showError("Ingresa tu email para recuperar la contraseña.");
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await FirebaseAnalytics.instance.logEvent(
        name: "password_reset_request",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Revisa tu correo para restablecerla.")),
      );
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? "No se pudo enviar el email.");
    } catch (_) {
      _showError("No se pudo enviar el email.");
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
                _isLogin ? "Iniciar sesion" : "Crear cuenta",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (!_isLogin)
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre visible",
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
                      : Text(_isLogin ? "Entrar" : "Crear cuenta"),
                ),
              ),
              if (_isLogin)
                TextButton(
                  onPressed: _isLoading ? null : _sendPasswordReset,
                  child: const Text("Olvidaste tu contraseña?"),
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
                      ? "No tienes cuenta? Registrate"
                      : "Ya tienes cuenta? Inicia sesion",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
