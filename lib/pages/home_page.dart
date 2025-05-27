import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openapi/openapi.dart';  // This now includes our enhanced APIs
import 'package:flutter_e_mentor/main.dart';
import 'package:flutter_e_mentor/api/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StudentStatsDTO? _dashboardStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      // Use our enhanced API with the proper serializers
      try {
        final quizzesApi = QuizzesControllerApi(ApiClient.dio, standardSerializers);
        final stats = await quizzesApi.getDashboardStats();
        
        setState(() {
          _dashboardStats = stats.data;
          _isLoading = false;
        });
        return;
      } catch (directError) {
        print('Direct API call failed: $directError');
      }
      
      // If we get here, we failed to parse the response
      setState(() {
        _error = "Couldn't parse the dashboard data";
        _isLoading = false;
      });
    } catch (e, stack) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error fetching dashboard stats: $e');
      print(stack);
    }
  }

  String? _getUserNameFromIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload['name'] ?? payload['preferred_username'] ?? payload['given_name'] ?? payload['sub'];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context);
    final userName = _getUserNameFromIdToken(userProfile.idToken) ?? 'Utilizator';
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BigCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bună,', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: theme.primaryColor)),
                      const SizedBox(height: 8),
                      Text(userName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: CupertinoColors.black)),
                    ],
                  ),
                ),
                
                if (_isLoading)
                  const _BigCard(
                    child: Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  )
                else if (_error != null)
                  _BigCard(
                    child: Column(
                      children: [
                        const Text('Nu s-au putut încărca datele', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          child: const Text('Reîncearcă'),
                          onPressed: _fetchDashboardStats,
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Quiz stats card
                  _BigCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Testele tale',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_dashboardStats?.quizzes?.completedQuizzes ?? 0} completate',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatRow(
                          label: 'Întrebări răspunse',
                          value: _dashboardStats?.questions?.totalQuestions?.toString() ?? '0',
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'Răspunsuri corecte',
                          value: _dashboardStats?.questions?.correctQuestions?.toString() ?? '0',
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'Timp petrecut (ultima lună)',
                          value: _formatTime(_dashboardStats?.lastMonthQuizTime ?? 0),
                        ),
                      ],
                    ),
                  ),
                  
                  // Recent results card if available
                  if (_dashboardStats?.lastMonthQuizzesResults?.isNotEmpty ?? false)
                    _BigCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rezultate recente',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          ..._buildRecentResults(),
                        ],
                      ),
                    ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildRecentResults() {
    final results = _dashboardStats?.lastMonthQuizzesResults?.toList() ?? [];
    if (results.isEmpty) return [];
    
    return results.take(5).map((result) {
      final date = result.date != null ? 
          '${result.date!.day}/${result.date!.month}/${result.date!.year}' : 
          'Data necunoscută';
      final percentage = result.result != null ? 
          (result.result! * 100).toStringAsFixed(0) + '%' : 
          'N/A';
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date, style: const TextStyle(fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getColorForResult(result.result ?? 0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                percentage,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  Color _getColorForResult(double result) {
    if (result >= 0.8) return const Color(0xFF28C76F); // Success
    if (result >= 0.5) return const Color(0xFFFFB155); // Warning
    return const Color(0xFFEA5455); // Danger
  }
  
  String _formatTime(int seconds) {
    if (seconds < 60) return '$seconds secunde';
    if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes minut${minutes == 1 ? '' : 'e'}';
    }
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    return '$hours or${hours == 1 ? 'ă' : 'e'} $minutes minut${minutes == 1 ? '' : 'e'}';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  
  const _StatRow({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: CupertinoColors.black)),
        Text(value, 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CupertinoColors.black)
        ),
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  final Widget child;
  const _BigCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
