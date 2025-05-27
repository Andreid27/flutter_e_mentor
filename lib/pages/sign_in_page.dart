import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/env.dart';
import '../main.dart';
import 'package:flutter_e_mentor/api/api_client.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthorizationTokenResponse? result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          Environment.keycloakClientId,
          Environment.keycloakRedirectUri,
          discoveryUrl: Environment.keycloakDiscoveryUrl,
          scopes: ['openid', 'profile', 'email'],
        ),
      );
      
      if (result != null) {
        await secureStorage.write(key: 'access_token', value: result.accessToken);
        await secureStorage.write(key: 'id_token', value: result.idToken);
        await secureStorage.write(key: 'refresh_token', value: result.refreshToken);
        
        // Update API client and Provider
        ApiClient.setBearerToken(result.accessToken);
        final userProfile = Provider.of<UserProfile>(context, listen: false);
        userProfile.updateTokens(
          access: result.accessToken,
          id: result.idToken,
          refresh: result.refreshToken,
        );
        
        // Redirect to home after login
        if (mounted) {
          GoRouter.of(context).go('/home');
        }
      }
    } catch (e, stack) {
      print('Login failed: $e');
      print(stack);
      setState(() {
        _errorMessage = 'Login failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGreen,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sign In', style: TextStyle(color: CupertinoColors.white)),
        backgroundColor: CupertinoColors.systemGreen,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo at the top with circular shaded background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'lib/resouces/e_mentor.ico',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    CupertinoIcons.person_solid,
                    size: 120,
                    color: CupertinoColors.white,
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            // Sign in button
            if (_isLoading)
              const CupertinoActivityIndicator(color: CupertinoColors.white)
            else
              CupertinoButton.filled(
                onPressed: _login,
                color: CupertinoColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                borderRadius: BorderRadius.circular(8),
                child: const Text(
                  'Sign into E-Mentor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemGreen,
                  ),
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: CupertinoColors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
