import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:openapi/openapi.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import '../api/api_client.dart';
import 'package:go_router/go_router.dart';

class QuizListPage extends StatefulWidget {
  const QuizListPage({super.key});

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

enum SortProperty {
  assignedAt('assignedAt', 'Data asignării'),
  title('title', 'Nume'),
  chapterTitles('chapterTitles', 'Capitol'),
  maxTime('maxTime', 'Durată'),
  difficultyLevel('difficultyLevel', 'Dificultate');

  const SortProperty(this.key, this.displayName);
  final String key;
  final String displayName;
}

enum DifficultyFilter {
  all('all', 'Toate nivelurile'),
  easy('1', 'Ușor'),
  medium('2', 'Mediu'),
  hard('3', 'Greu');

  const DifficultyFilter(this.value, this.displayName);
  final String value;
  final String displayName;
}

enum ComponentTypeFilter {
  all('all', 'Toate tipurile'),
  generalChapters('CG', '📚 Complement grupat'),
  specificChapters('CS', '🎯 Complement simplu');

  const ComponentTypeFilter(this.value, this.displayName);
  final String value;
  final String displayName;
  
  QuizzesStudentsViewComponentTypeEnum? get enumValue {
    switch (this) {
      case ComponentTypeFilter.generalChapters:
        return QuizzesStudentsViewComponentTypeEnum.CG;
      case ComponentTypeFilter.specificChapters:
        return QuizzesStudentsViewComponentTypeEnum.CS;
      default:
        return null;
    }
  }
}

class _QuizListPageState extends State<QuizListPage> {
  List<QuizzesStudentsView> _quizzes = [];
  List<FilterOptionObject> _filterOptions = [];
  bool _loading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalCount = 0;
  final int _pageSize = 10;
  SortProperty _orderBy = SortProperty.assignedAt;
  SortCriteriaDirectionEnum _order = SortCriteriaDirectionEnum.DESC;
  late ScrollController _scrollController;
  
  // Filters
  DifficultyFilter _difficultyFilter = DifficultyFilter.all;
  ComponentTypeFilter _componentTypeFilter = ComponentTypeFilter.all;
  String _searchQuery = '';
  
  late QuizzesControllerApi _quizzesApi;

  @override
  void initState() {
    super.initState();
    // Initialize the API client using the generated API
    final openapi = Openapi(dio: ApiClient.dio);
    _quizzesApi = openapi.getQuizzesControllerApi();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadQuizzes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _quizzes.length < _totalCount) {
      _loadMoreQuizzes();
    }
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
    });

    try {
      // Create the paginated request with sorters similar to the web implementation
      final sorters = ListBuilder<SortCriteria>();
      
      // Always add assignedAt as primary sort
      sorters.add(SortCriteria((b) => b
        ..key = SortProperty.assignedAt.key
        ..direction = _order));
      
      // Add the selected sort criteria if it's different from assignedAt
      if (_orderBy != SortProperty.assignedAt) {
        sorters.add(SortCriteria((b) => b
          ..key = _orderBy.key
          ..direction = _order));
      }

      // Build filters using the generated enum types
      final filters = ListBuilder<FilterCriteriaObject>();
      
      // Add difficulty filter
      if (_difficultyFilter != DifficultyFilter.all) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'difficultyLevel'
          ..operation = FilterCriteriaObjectOperationEnum.EQUAL
          ..value = JsonObject(int.parse(_difficultyFilter.value))));
      }
      
      // Add component type filter
      if (_componentTypeFilter != ComponentTypeFilter.all) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'componentType'
          ..operation = FilterCriteriaObjectOperationEnum.EQUAL
          ..value = JsonObject(_componentTypeFilter.value)));
      }
      
      // Add search filter
      if (_searchQuery.isNotEmpty) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'title'
          ..operation = FilterCriteriaObjectOperationEnum.LIKE
          ..value = JsonObject(_searchQuery)));
      }

      final request = PaginatedRequest((b) => b
        ..filters = filters
        ..sorters = sorters
        ..page = _currentPage
        ..pageSize = _pageSize);

      // Call the assigned-paginated endpoint (matching the web implementation)
      final response = await _quizzesApi.getPaginatedQuizStudent(
        paginatedRequest: request,
      );

      if (response.data != null) {
        setState(() {
          _quizzes = response.data!.data?.toList() ?? [];
          _totalCount = response.data!.totalCount ?? 0;
          _filterOptions = response.data!.filterOptions?.toList() ?? [];
          _loading = false;
        });
      }
    } catch (error) {
      print('Error loading quizzes: $error');
      setState(() {
        _loading = false;
      });
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: const Text('Eroare'),
            content: Text('Eroare la încărcarea testelor: $error'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadMoreQuizzes() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    try {
      final sorters = ListBuilder<SortCriteria>();
      sorters.add(SortCriteria((b) => b
        ..key = SortProperty.assignedAt.key
        ..direction = _order));
      if (_orderBy != SortProperty.assignedAt) {
        sorters.add(SortCriteria((b) => b
          ..key = _orderBy.key
          ..direction = _order));
      }
      final filters = ListBuilder<FilterCriteriaObject>();
      if (_difficultyFilter != DifficultyFilter.all) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'difficultyLevel'
          ..operation = FilterCriteriaObjectOperationEnum.EQUAL
          ..value = JsonObject(int.parse(_difficultyFilter.value))));
      }
      if (_componentTypeFilter != ComponentTypeFilter.all) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'componentType'
          ..operation = FilterCriteriaObjectOperationEnum.EQUAL
          ..value = JsonObject(_componentTypeFilter.value)));
      }
      if (_searchQuery.isNotEmpty) {
        filters.add(FilterCriteriaObject((b) => b
          ..key = 'title'
          ..operation = FilterCriteriaObjectOperationEnum.LIKE
          ..value = JsonObject(_searchQuery)));
      }
      final request = PaginatedRequest((b) => b
        ..filters = filters
        ..sorters = sorters
        ..page = _currentPage
        ..pageSize = _pageSize);
      final response = await _quizzesApi.getPaginatedQuizStudent(
        paginatedRequest: request,
      );
      if (response.data != null) {
        setState(() {
          _quizzes.addAll(response.data!.data?.toList() ?? []);
          _isLoadingMore = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _handleSort(SortProperty property) {
    setState(() {
      if (_orderBy == property) {
        _order = _order == SortCriteriaDirectionEnum.ASC 
            ? SortCriteriaDirectionEnum.DESC 
            : SortCriteriaDirectionEnum.ASC;
      } else {
        _orderBy = property;
        _order = SortCriteriaDirectionEnum.ASC;
      }
      _currentPage = 0;
    });
    _loadQuizzes();
  }

  void _handleDifficultyFilter(DifficultyFilter filter) {
    setState(() {
      _difficultyFilter = filter;
      _currentPage = 0;
    });
    _loadQuizzes();
  }

  void _handleComponentTypeFilter(ComponentTypeFilter filter) {
    setState(() {
      _componentTypeFilter = filter;
      _currentPage = 0;
    });
    _loadQuizzes();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
    });
    _loadQuizzes();
  }

  void _showDifficultyFilter() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Selectează dificultatea'),
        actions: DifficultyFilter.values.map((filter) => 
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _handleDifficultyFilter(filter);
            },
            child: Text(filter.displayName),
          ),
        ).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulează'),
        ),
      ),
    );
  }

  void _showComponentTypeFilter() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Selectează tipul componentei'),
        actions: ComponentTypeFilter.values.map((filter) => 
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _handleComponentTypeFilter(filter);
            },
            child: Text(filter.displayName),
          ),
        ).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulează'),
        ),
      ),
    );
  }

  void _showSortOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Sortează după'),
        actions: SortProperty.values.map((property) => 
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _handleSort(property);
            },
            child: Text(property.displayName),
          ),
        ).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulează'),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _difficultyFilter = DifficultyFilter.all;
      _componentTypeFilter = ComponentTypeFilter.all;
      _searchQuery = '';
      _currentPage = 0;
    });
    _loadQuizzes();
  }

  void _navigateToQuizPreview(String quizId) {
    Navigator.pushNamed(context, '/quiz/$quizId');
  }

  Color _calculateRowColor(int? correctAnswers, int? questionsCount) {
    if (correctAnswers == null || questionsCount == null || questionsCount == 0) {
      return Colors.grey.withOpacity(0.1);
    }
    
    final correctPercentage = correctAnswers / questionsCount;
    
    if (correctPercentage == 0) {
      return Colors.red.withOpacity(0.1);
    } else if (correctPercentage < 0.5) {
      return Colors.orange.withOpacity(0.1);
    } else {
      return Colors.green.withOpacity(0.1);
    }
  }

  String _formatDuration(int? maxTime) {
    if (maxTime == null) return '-';
    final hours = maxTime ~/ 60;
    final minutes = maxTime % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _getDifficultyText(int? level) {
    if (level == null) return '-';
    // Create a mapping that matches our DifficultyFilter enum
    const difficultyMap = {
      1: 'Ușor',
      2: 'Mediu', 
      3: 'Greu',
    };
    return difficultyMap[level] ?? 'Nivel $level';
  }

  String _getComponentTypeText(QuizzesStudentsViewComponentTypeEnum? componentType) {
    if (componentType == null) return '';
    // Use the enum values directly from the generated types
    if (componentType == QuizzesStudentsViewComponentTypeEnum.CG) {
      return '📚 Capitole generale';
    } else if (componentType == QuizzesStudentsViewComponentTypeEnum.CS) {
      return '🎯 Capitole specifice';
    } else {
      return componentType.name;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    // Simple date formatting without intl package
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Testele tale'),
        backgroundColor: CupertinoTheme.of(context).primaryColor,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.white),
          onPressed: _loadQuizzes,
        ),
      ),
      child: _loading
          ? const Center(
              child: CupertinoActivityIndicator(
                radius: 12,
              ),
            )
          : _totalCount == 0
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFiltersSection(),
                    Expanded(child: _buildQuizList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.question_circle,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'Nu ai niciun test asignat',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contactează-ți profesorul pentru a începe testele.',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoColors.systemGrey2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CupertinoTextField(
              onChanged: _handleSearch,
              placeholder: 'Caută teste...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(
                  CupertinoIcons.search,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: null, // Remove default decoration
            ),
          ),
          const SizedBox(height: 12),
          
          // Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Difficulty filter
                      GestureDetector(
                        onTap: _showDifficultyFilter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _difficultyFilter != DifficultyFilter.all 
                                ? CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _difficultyFilter != DifficultyFilter.all 
                                  ? CupertinoTheme.of(context).primaryColor
                                  : CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _difficultyFilter.displayName,
                                style: TextStyle(
                                  color: _difficultyFilter != DifficultyFilter.all 
                                      ? CupertinoTheme.of(context).primaryColor
                                      : CupertinoColors.label,
                                ),
                              ),
                              if (_difficultyFilter != DifficultyFilter.all) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _handleDifficultyFilter(DifficultyFilter.all),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 16,
                                    color: CupertinoTheme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Component type filter
                      GestureDetector(
                        onTap: _showComponentTypeFilter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _componentTypeFilter != ComponentTypeFilter.all 
                                ? CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _componentTypeFilter != ComponentTypeFilter.all 
                                  ? CupertinoTheme.of(context).primaryColor
                                  : CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _componentTypeFilter.displayName,
                                style: TextStyle(
                                  color: _componentTypeFilter != ComponentTypeFilter.all 
                                      ? CupertinoTheme.of(context).primaryColor
                                      : CupertinoColors.label,
                                ),
                              ),
                              if (_componentTypeFilter != ComponentTypeFilter.all) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _handleComponentTypeFilter(ComponentTypeFilter.all),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 16,
                                    color: CupertinoTheme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Clear filters button
              if (_difficultyFilter != DifficultyFilter.all || 
                  _componentTypeFilter != ComponentTypeFilter.all ||
                  _searchQuery.isNotEmpty)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onPressed: _clearFilters,
                  child: Text(
                    'Șterge filtrele',
                    style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
                  ),
                ),
            ],
          ),
          
          // Display dynamic filter options from API (if available)
          if (_filterOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Opțiuni disponibile: ${_filterOptions.length}',
              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizList() {
    return Column(
      children: [
        // Sort options
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Sortează după: '),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showSortOptions(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CupertinoColors.systemGrey4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_orderBy.displayName),
                        const Icon(CupertinoIcons.chevron_down),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                child: Icon(_order == SortCriteriaDirectionEnum.ASC 
                    ? CupertinoIcons.arrow_up 
                    : CupertinoIcons.arrow_down),
                onPressed: () => _handleSort(_orderBy),
              ),
            ],
          ),
        ),
        // Quiz list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _quizzes.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _quizzes.length) {
                // Loading indicator for pagination
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              final quiz = _quizzes[index];
              final correctPercentage = quiz.correctAnswers != null && 
                      quiz.questionsCount != null && 
                      quiz.questionsCount! > 0
                  ? quiz.correctAnswers! / quiz.questionsCount!
                  : 0.0;

              return GestureDetector(
                onTap: () {
                  print('🔗 Attempting to navigate to: /quiz-preview/${quiz.id}');
                  context.go('/quiz-preview/${quiz.id}');
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: _calculateRowColor(quiz.correctAnswers, quiz.questionsCount),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quiz.title ?? 'Test fără nume',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Component type
                              if (quiz.componentType != null) ...[
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.tag, size: 16, color: CupertinoColors.systemIndigo),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getComponentTypeText(quiz.componentType),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              // Chapter titles
                              if (quiz.chapterTitles != null) ...[
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.book, size: 16, color: CupertinoColors.systemBlue),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        quiz.chapterTitles!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              // Duration and difficulty
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.clock, size: 16, color: CupertinoColors.systemOrange),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(quiz.maxTime),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(CupertinoIcons.speedometer, size: 16, color: CupertinoColors.systemPurple),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getDifficultyText(quiz.difficultyLevel),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              // Correct answers
                              if (quiz.correctAnswers != null && quiz.questionsCount != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.checkmark_circle, size: 16, color: CupertinoColors.systemGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.correctAnswers}/${quiz.questionsCount} corecte (${(correctPercentage * 100).toStringAsFixed(1)}%)',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                              // Assignment date
                              if (quiz.assignedAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.calendar, size: 16, color: CupertinoColors.systemGrey),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Asignat: ${_formatDateTime(quiz.assignedAt)}',
                                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                                    ),
                                  ],
                                ),
                              ],
                              // Started date
                              if (quiz.startedAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.play, size: 16, color: CupertinoColors.systemBlue),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Început: ${_formatDateTime(quiz.startedAt)}',
                                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                                    ),
                                  ],
                                ),
                              ],
                              // End time
                              if (quiz.endedTime != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.stop, size: 16, color: CupertinoColors.systemRed),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Terminat: ${_formatDateTime(quiz.endedTime)}',
                                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Remove old pagination info
      ],
    );
  }
}
