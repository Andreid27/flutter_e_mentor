import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/env.dart';
import 'pages/home_page.dart';
import 'pages/quiz_list_page.dart';
import 'pages/quiz_details_page.dart';
import 'pages/sign_in_page.dart';
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
  final idToken = await secureStorage.read(key: 'id_token');
  final refreshToken = await secureStorage.read(key: 'refresh_token');
  ApiClient.setBearerToken(accessToken);

  // Create UserProfile instance and initialize with stored tokens
  final userProfile = UserProfile();
  if (accessToken != null && accessToken.isNotEmpty) {
    userProfile.updateTokens(
      access: accessToken,
      id: idToken,
      refresh: refreshToken,
    );
  }

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
    ChangeNotifierProvider.value(
      value: userProfile,
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
