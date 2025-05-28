import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:openapi/openapi.dart';
import 'package:built_value/json_object.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';

class QuizPreviewPage extends StatefulWidget {
  final String quizId;
  final String? userRole;
  const QuizPreviewPage({Key? key, required this.quizId, this.userRole}) : super(key: key);

  @override
  State<QuizPreviewPage> createState() => _QuizPreviewPageState();
}

class _QuizPreviewPageState extends State<QuizPreviewPage> {
  bool _loading = true;
  QuizzesStudentsView? _previewMetadata;
  String? _error;
  late QuizzesControllerApi _quizzesApi;

  @override
  void initState() {
    super.initState();
    final openapi = Openapi(dio: ApiClient.dio);
    _quizzesApi = openapi.getQuizzesControllerApi();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Use paginated endpoint to fetch quiz by ID
      final request = PaginatedRequest((b) => b
        ..filters.add(FilterCriteriaObject((b) => b
          ..key = 'id'
          ..operation = FilterCriteriaObjectOperationEnum.EQUAL
          ..value = JsonObject(widget.quizId)))
        ..page = 0
        ..pageSize = 1);
      final response = await _quizzesApi.getPaginatedQuizStudent(paginatedRequest: request);
      final data = response.data?.data;
      if (data != null && data.isNotEmpty) {
        setState(() {
          _previewMetadata = data.first;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Nu s-au găsit date pentru acest test.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Eroare la încărcarea testului: $e';
        _loading = false;
      });
    }
  }

  void _handleBack() {
    print('DEBUG: Back button pressed in QuizPreviewPage');
    // Check if we can pop, otherwise navigate to a safe route
    if (context.canPop()) {
      context.pop();
    } else {
      // Navigate to quiz list or home if there's nothing to pop
      context.go('/quizzes');
    }
  }

  void _handleStartTest() {
    print('DEBUG: Start test button pressed for quiz ID: ${widget.quizId}');
    // Navigate to quiz attempt page (implement as needed)
    context.push('/quiz_attempt/${widget.quizId}');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Previzualizare test'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: _handleBack,
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : _error != null
              ? Center(child: Text(_error!))
              : _previewMetadata == null
                  ? Center(child: Text('Nu există date pentru acest test.'))
                  : _buildPreviewContent(),
    );
  }

  Widget _buildPreviewContent() {
    final meta = _previewMetadata!;
    // For demo: fallback values if null
    final title = meta.title ?? '-';
    final description = meta.description ?? '';
    final chapters = (meta.chapterTitles != null) ? [meta.chapterTitles!] : [];
    final questionsCount = meta.questionsCount ?? 0;
    final maxTime = meta.maxTime ?? 0;
    final difficulty = meta.difficultyLevel ?? 1;
    final componentType = meta.componentType?.name ?? '';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card - Title and Description
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description, 
                      style: const TextStyle(
                        fontSize: 16, 
                        color: CupertinoColors.secondaryLabel,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quiz Details Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.info_circle, 
                           color: CupertinoColors.activeBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Detalii test',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: CupertinoIcons.list_bullet,
                    label: 'Întrebări',
                    value: '$questionsCount',
                  ),
                  _buildDetailRow(
                    icon: CupertinoIcons.time,
                    label: 'Timp alocat',
                    value: '$maxTime minute',
                  ),
                  _buildDetailRow(
                    icon: CupertinoIcons.star_fill,
                    label: 'Dificultate',
                    value: '$difficulty/3',
                    iconColor: CupertinoColors.systemYellow,
                  ),
                  if (componentType.isNotEmpty)
                    _buildDetailRow(
                      icon: CupertinoIcons.book,
                      label: 'Tip',
                      value: componentType,
                    ),
                ],
              ),
            ),
            
            // Chapters Card (if any)
            if (chapters.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.book_circle, 
                             color: CupertinoColors.activeBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Capitole',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...chapters.map((chapter) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              chapter,
                              style: const TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.label,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Debug Card (temporary)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.gear, 
                           color: CupertinoColors.systemGrey, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Info',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quiz ID: ${widget.quizId}\nRole: ${widget.userRole}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons Card
            _buildCard(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text('Înapoi'),
                      onPressed: _handleBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(widget.userRole == 'STUDENT' ? 'Start test' : 'Vezi test'),
                      onPressed: _handleStartTest,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            // TODO: Add previous attempts section
          ],
        ),
      ),
    );
  }
  
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
  
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon, 
            color: iconColor ?? CupertinoColors.activeBlue, 
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }
}