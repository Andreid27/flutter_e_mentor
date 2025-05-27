import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/env.dart';
import 'pages/home_page.dart';
import 'pages/quiz_list_page.dart';
import 'pages/quiz_details_page.dart';
import 'api/api_client.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

// User profile model for Provider
class UserProfile extends ChangeNotifier {
  String? name;
  String? email;
  String? accessToken;
  String? idToken;
  String? refreshToken;

  void updateTokens({String? access, String? id, String? refresh}) {
    accessToken = access;
    idToken = id;
    refreshToken = refresh;
    notifyListeners();
  }

  void updateProfile({String? newName, String? newEmail}) {
    name = newName;
    email = newEmail;
    notifyListeners();
  }

  void clear() {
    name = null;
    email = null;
    accessToken = null;
    idToken = null;
    refreshToken = null;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize API client with base URL
  ApiClient.initialize(Environment.apiBaseUrl);
  
  // Set up the Bearer token for API calls if available
  final secureStorage = FlutterSecureStorage();
  final accessToken = await secureStorage.read(key: 'access_token');
  ApiClient.setBearerToken(accessToken);

  final GoRouter _router = GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final userProfile = Provider.of<UserProfile>(context, listen: false);
      final loggedIn = userProfile.accessToken != null && userProfile.accessToken!.isNotEmpty;
      final loggingIn = state.fullPath == '/sign-in';
      if (!loggedIn && !loggingIn) return '/sign-in';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/quizzes',
            builder: (context, state) => const QuizListPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => QuizDetailsPage(quizId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProfile(),
      child: MyApp(router: _router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});
  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      title: 'Flutter Demo',
      theme: cupertinoThemeFromWebPalette(),
      routerConfig: router,
    );
  }
}

CupertinoThemeData cupertinoThemeFromWebPalette() {
  // Colors from index.js
  const primary = Color.fromRGBO(40, 199, 111, 1); // #28C76F
  const primaryDark = Color(0xFF22B86B);
  const background = Color(0xFFFFFFFF); // Always white
  const barBackground = Color(0xFFFFFFFF);
  const textColor = Color.fromRGBO(47, 43, 61, 0.78);
  return const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    primaryContrastingColor: primaryDark,
    barBackgroundColor: barBackground,
    scaffoldBackgroundColor: background,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: textColor, fontFamily: 'SF Pro Text'),
      navTitleTextStyle: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
      navLargeTitleTextStyle: TextStyle(color: textColor, fontSize: 34, fontWeight: FontWeight.bold),
      actionTextStyle: TextStyle(color: primary, fontSize: 17),
    ),
  );
}

class MainScaffold extends StatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  static const List<String> _routes = ['/home', '/quizzes'];
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    context.go(_routes[index]);
  }
  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Container(
      color: CupertinoColors.white,
      child: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: SafeArea(
              child: widget.child,
            ),
          ),
          // Floating nav bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: theme.barBackgroundColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarItem(
                    icon: CupertinoIcons.home,
                    label: 'Home',
                    selected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                    activeColor: theme.primaryColor,
                  ),
                  _NavBarItem(
                    icon: CupertinoIcons.list_bullet,
                    label: 'Quizzes',
                    selected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });
  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : CupertinoColors.inactiveGray;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String? _accessToken;
  String? _idToken;
  String? _refreshToken;
  String? _errorMessage;

  Future<void> _login() async {
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
        setState(() {
          _accessToken = result.accessToken;
          _idToken = result.idToken;
          _refreshToken = result.refreshToken;
          _errorMessage = null;
        });
        // Update Provider
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
    }
  }

  Future<void> _refreshTokens() async {
    try {
      final storedRefreshToken = await secureStorage.read(key: 'refresh_token');
      if (storedRefreshToken == null) {
        setState(() {
          _errorMessage = 'No refresh token available.';
        });
        return;
      }
      final TokenResponse? response = await appAuth.token(TokenRequest(
        Environment.keycloakClientId,
        Environment.keycloakRedirectUri,
        discoveryUrl: Environment.keycloakDiscoveryUrl,
        refreshToken: storedRefreshToken,
        scopes: ['openid', 'profile', 'email'],
      ));
      if (response != null) {
        await secureStorage.write(key: 'access_token', value: response.accessToken);
        await secureStorage.write(key: 'id_token', value: response.idToken);
        await secureStorage.write(key: 'refresh_token', value: response.refreshToken ?? storedRefreshToken);
        setState(() {
          _accessToken = response.accessToken;
          _idToken = response.idToken;
          _refreshToken = response.refreshToken ?? storedRefreshToken;
          _errorMessage = null;
        });
        // Update Provider
        final userProfile = Provider.of<UserProfile>(context, listen: false);
        userProfile.updateTokens(
          access: response.accessToken,
          id: response.idToken,
          refresh: response.refreshToken ?? storedRefreshToken,
        );
      }
    } catch (e, stack) {
      print('Token refresh failed: $e');
      print(stack);
      setState(() {
        _errorMessage = 'Token refresh failed: $e';
      });
    }
  }

  // Helper to decode JWT and check expiry
  bool _isTokenExpired(String? token) {
    if (token == null) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Consider token expired if less than 1 minute left
      return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 1)));
    } catch (_) {
      return true;
    }
  }

  // Use this to get a valid access token (auto-refresh if needed)
  Future<String?> getValidAccessToken() async {
    if (_isTokenExpired(_accessToken)) {
      await _refreshTokens();
    }
    return _accessToken;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sign In'),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_accessToken == null) ...[
                  CupertinoButton.filled(
                    onPressed: _login,
                    child: const Text('Login with Keycloak'),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(color: CupertinoColors.systemRed)),
                  ],
                ] else ...[
                  const Text('Logged in!'),
                  const SizedBox(height: 16),
                  Consumer<UserProfile>(
                    builder: (context, profile, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Access Token:'),
                        SelectableText(profile.accessToken ?? '', style: TextStyle(fontSize: 12)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: profile.accessToken == null ? null : () async {
                            await Clipboard.setData(ClipboardData(text: profile.accessToken ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Access token copied!')),
                            );
                          },
                          child: const Icon(CupertinoIcons.doc_on_doc),
                        ),
                        const SizedBox(height: 16),
                        const Text('ID Token:'),
                        SelectableText(profile.idToken ?? '', style: TextStyle(fontSize: 12)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: profile.idToken == null ? null : () async {
                            await Clipboard.setData(ClipboardData(text: profile.idToken ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID token copied!')),
                            );
                          },
                          child: const Icon(CupertinoIcons.doc_on_doc),
                        ),
                        const SizedBox(height: 16),
                        const Text('Refresh Token:'),
                        SelectableText(profile.refreshToken ?? '', style: TextStyle(fontSize: 12)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: profile.refreshToken == null ? null : () async {
                            await Clipboard.setData(ClipboardData(text: profile.refreshToken ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Refresh token copied!')),
                            );
                          },
                          child: const Icon(CupertinoIcons.doc_on_doc),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    onPressed: _refreshTokens,
                    child: const Text('Refresh Tokens'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
