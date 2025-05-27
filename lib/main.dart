import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

// Keycloak configuration
const String KEYCLOAK_ISSUER = 'https://dev.api.e-mentor.ro/auth/realms/e-mentor';
const String KEYCLOAK_CLIENT_ID = 'e-mentor';
const String KEYCLOAK_REDIRECT_URI = 'com.example.flutterementor://login-callback'; // Update this in Keycloak client settings
const String KEYCLOAK_DISCOVERY_URL =
    'https://dev.api.e-mentor.ro/auth/realms/e-mentor/.well-known/openid-configuration';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _accessToken;
  String? _idToken;
  String? _refreshToken;
  String? _errorMessage;

  Future<void> _login() async {
    try {
      final AuthorizationTokenResponse? result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          KEYCLOAK_CLIENT_ID,
          KEYCLOAK_REDIRECT_URI,
          discoveryUrl: KEYCLOAK_DISCOVERY_URL,
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
      }
    } catch (e, stack) {
      print('Login failed: \$e');
      print(stack);
      setState(() {
        _errorMessage = 'Login failed: \$e';
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
        KEYCLOAK_CLIENT_ID,
        KEYCLOAK_REDIRECT_URI,
        discoveryUrl: KEYCLOAK_DISCOVERY_URL,
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
      }
    } catch (e, stack) {
      print('Token refresh failed: \$e');
      print(stack);
      setState(() {
        _errorMessage = 'Token refresh failed: \$e';
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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_accessToken == null) ...[
              ElevatedButton(
                onPressed: _login,
                child: const Text('Login with Keycloak'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ] else ...[
              const Text('Logged in!'),
              const SizedBox(height: 16),
              const Text('Access Token:'),
              SelectableText(_accessToken ?? '', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Access Token',
                onPressed: _accessToken == null ? null : () async {
                  await Clipboard.setData(ClipboardData(text: _accessToken ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Access token copied!')),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('ID Token:'),
              SelectableText(_idToken ?? '', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy ID Token',
                onPressed: _idToken == null ? null : () async {
                  await Clipboard.setData(ClipboardData(text: _idToken ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID token copied!')),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Refresh Token:'),
              SelectableText(_refreshToken ?? '', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Refresh Token',
                onPressed: _refreshToken == null ? null : () async {
                  await Clipboard.setData(ClipboardData(text: _refreshToken ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refresh token copied!')),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshTokens,
                child: const Text('Refresh Tokens'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
