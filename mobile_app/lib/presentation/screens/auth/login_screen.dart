import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SCR-001: Registration / Login screen.
/// Flow: phone → OTP code → name (if new user).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  int _step = 0; // 0 = phone, 1 = code, 2 = name

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    // TODO: call POST /auth/send-code via Dio
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _step = 1;
      _isLoading = false;
    });
  }

  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);
    // TODO: call POST /auth/login with phone + code
    // If is_new → go to step 2, else navigate to home
    await Future.delayed(const Duration(milliseconds: 500));
    final isNew = true; // mock
    setState(() {
      _isLoading = false;
      if (isNew) {
        _step = 2;
      } else {
        // Navigate to home
      }
    });
  }

  Future<void> _setName() async {
    setState(() => _isLoading = true);
    // TODO: call PATCH /profile with name
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
    // Navigate to home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo / Title
              Text(
                'Волна 🏄',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Запишись на сапбординг-прогулку',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Step-specific content
              if (_step == 0) ...[
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: '+7 (999) 000-00-00',
                    prefixIcon: Icon(Icons.phone_outlined),
                    labelText: 'Номер телефона',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Получить код'),
                ),
              ],

              if (_step == 1) ...[
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    hintText: '0000',
                    prefixIcon: Icon(Icons.lock_outline),
                    labelText: 'Код из SMS',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Войти'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('← Другой номер'),
                ),
              ],

              if (_step == 2) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Ваше имя',
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: 'Как вас зовут?',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _setName,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Начать'),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
