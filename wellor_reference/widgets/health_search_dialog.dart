import '../theme/app_theme.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/health_subcategories_data.dart';
import '../services/health_ai_search_service.dart';
import '../providers/subscription_provider.dart';

/// UNICORN GRADE: AI-Powered Health Profile Editor
/// Features: 1000+ Health Items, Natural Language AI Search, 
/// Category Navigation, and Neural-Haptic Feedback
class HealthSearchDialog extends StatefulWidget {
  final Function(List<String>) onDiseasesSelected;
  final Function(List<String>) onGoalsSelected;
  final List<String> initialDiseases;
  final List<String> initialGoals;
  final bool isGoalsTab;
  final bool showOnlyGoals;
  final bool showOnlyConditions;

  const HealthSearchDialog({
    super.key,
    required this.onDiseasesSelected,
    required this.onGoalsSelected,
    this.initialDiseases = const [],
    this.initialGoals = const [],
    this.isGoalsTab = false,
    this.showOnlyGoals = false,
    this.showOnlyConditions = false,
  });

  @override
  State<HealthSearchDialog> createState() => _HealthSearchDialogState();
}

class _HealthSearchDialogState extends State<HealthSearchDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  final TextEditingController _searchController = TextEditingController();

  List<String> _selectedDiseases = [];
  List<String> _selectedGoals = [];
  
  String? _activeGoalCategory;
  String? _activeConditionCategory;
  
  // AI Search State
  bool _isAISearching = false;
  bool _useAISearch = false;
  List<AISearchResult> _aiResults = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.showOnlyGoals ? 1 : 2,
      vsync: this,
      initialIndex: widget.showOnlyGoals ? 0 : (widget.isGoalsTab ? 1 : 0)
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _selectedDiseases = List.from(widget.initialDiseases);
    _selectedGoals = List.from(widget.initialGoals);

    _searchController.addListener(_onSearchChanged);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchController.clear();
          _searchQuery = '';
          _useAISearch = false;
          _aiResults = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      if (_searchQuery.isEmpty) {
        _useAISearch = false;
        _aiResults = [];
      }
    });
  }

  Future<void> _performAISearch() async {
    if (_searchQuery.trim().isEmpty) return;
    
    setState(() {
      _isAISearching = true;
      _useAISearch = true;
    });
    
    HapticFeedback.mediumImpact();
    
    // Fix: Properly determine if searching for goals
    // When showOnlyGoals is true, we're always searching goals (even at index 0)
    // When showOnlyConditions is true, we're always searching conditions
    // Otherwise, index 1 = goals, index 0 = conditions
    final bool isGoals = widget.showOnlyGoals || 
                         (!widget.showOnlyConditions && _tabController.index == 1);
    
    final results = HealthAISearchService.performAISearch(
      _searchQuery,
      searchGoals: isGoals,
      searchConditions: !isGoals,
    );
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    setState(() {
      _aiResults = results;
      _isAISearching = false;
    });
  }

  void _handleToggle(String item, bool isDisease) {
    HapticFeedback.mediumImpact();
    if (!isDisease) {
      final maxGoals = context.read<SubscriptionProvider>().maxHealthGoals;
      if (!_selectedGoals.contains(item) &&
          maxGoals >= 0 &&
          _selectedGoals.length >= maxGoals) {
        final tierLabel = maxGoals == 6
            ? 'Premium allows up to 6 health goals'
            : 'Your plan allows up to $maxGoals health goals';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$tierLabel. Upgrade to Ultra for unlimited goals.',
            ),
          ),
        );
        return;
      }
    }
    setState(() {
      if (isDisease) {
        _selectedDiseases.contains(item)
            ? _selectedDiseases.remove(item)
            : _selectedDiseases.add(item);
      } else {
        _selectedGoals.contains(item)
            ? _selectedGoals.remove(item)
            : _selectedGoals.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        width: double.maxFinite,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (!_useAISearch && _searchQuery.isEmpty) _buildAIHint(),
            if (_useAISearch && _aiResults.isNotEmpty && !_isAISearching)
              _buildAIResultsHeader(),
            _buildTabs(),
            if (!_useAISearch) _buildCategoryPills(),
            Expanded(
              child: _useAISearch && _aiResults.isNotEmpty
                  ? _buildAIResultsList()
                  : widget.showOnlyGoals
                      ? _buildGoalsList()
                      : widget.showOnlyConditions
                          ? _buildConditionsList()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildConditionsList(),
                                _buildGoalsList(),
                              ],
                            ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Select Items',
              style: TextStyle(
                color: AppColors.onyx,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.vitality.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedDiseases.length + _selectedGoals.length} selected',
              style: const TextStyle(
                color: AppColors.vitality,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.slate),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.onyx),
              onSubmitted: (_) => _performAISearch(),
              decoration: InputDecoration(
                hintText: 'Describe symptoms or search...',
                hintStyle: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  _useAISearch ? Icons.auto_awesome : Icons.search,
                  color: _useAISearch ? AppColors.vitality : AppColors.slate,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _useAISearch = false;
                            _aiResults = [];
                          });
                        },
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.slate,
                          size: 18,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // AI Search Button
          GestureDetector(
            onTap: _isAISearching ? null : _performAISearch,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.onyx,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onyx.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isAISearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.vitality.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: AppColors.vitality),
                SizedBox(width: 4),
                Text(
                  'AI Search',
                  style: TextStyle(
                    color: AppColors.vitality,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Try: "always tired", "heart racing", "trouble sleeping"',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.vitality.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.vitality),
                const SizedBox(width: 6),
                Text(
                  '${_aiResults.length} AI Matches',
                  style: const TextStyle(
                    color: AppColors.vitality,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              _useAISearch = false;
              _aiResults = [];
            }),
            icon: const Icon(Icons.list, size: 14),
            label: const Text('Browse All'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.slate,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    if (widget.showOnlyGoals) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.vitality, width: 3)),
          ),
          child: Text(
            'GOALS (${_selectedGoals.length})',
            style: const TextStyle(
              color: AppColors.vitality,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    if (widget.showOnlyConditions) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.vitality, width: 3)),
          ),
          child: Text(
            'CONDITIONS (${_selectedDiseases.length})',
            style: const TextStyle(
              color: AppColors.vitality,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.vitality,
        indicatorWeight: 3,
        labelColor: AppColors.vitality,
        unselectedLabelColor: AppColors.slate,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
        ),
        tabs: [
          Tab(text: 'CONDITIONS (${_selectedDiseases.length})'),
          Tab(text: 'GOALS (${_selectedGoals.length})'),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    final isGoals = widget.showOnlyGoals || (!widget.showOnlyConditions && _tabController.index == 1);
    final categories = isGoals
        ? HealthSubcategoriesData.healthGoalCategoryNames
        : HealthSubcategoriesData.diseaseCategoryNames;
    final activeCategory = isGoals ? _activeGoalCategory : _activeConditionCategory;

    return SizedBox(
      height: 50,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          _buildPill(
            label: 'All',
            isActive: activeCategory == null,
            onTap: () => setState(() {
              if (isGoals) {
                _activeGoalCategory = null;
              } else {
                _activeConditionCategory = null;
              }
            }),
            color: AppColors.vitality,
          ),
          ...categories.map((cat) {
            return _buildPill(
              label: cat.replaceAll(RegExp(r'^[^\s]+\s'), ''),
              isActive: activeCategory == cat,
              onTap: () => setState(() {
                if (isGoals) {
                  _activeGoalCategory = cat;
                } else {
                  _activeConditionCategory = cat;
                }
              }),
              color: HealthSubcategoriesData.getCategoryColor(cat),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.onyx,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsList() {
    List<String> items;
    if (_searchQuery.isNotEmpty && !_useAISearch) {
      items = HealthSubcategoriesData.searchDiseaseConditions(_searchQuery);
    } else if (_activeConditionCategory != null) {
      items = HealthSubcategoriesData.diseaseCategories[_activeConditionCategory]!;
    } else {
      items = HealthSubcategoriesData.allDiseaseConditions;
    }

    return _buildItemsList(items, _selectedDiseases, true);
  }

  Widget _buildGoalsList() {
    List<String> items;
    if (_searchQuery.isNotEmpty && !_useAISearch) {
      items = HealthSubcategoriesData.searchHealthGoals(_searchQuery);
    } else if (_activeGoalCategory != null) {
      items = HealthSubcategoriesData.healthGoalCategories[_activeGoalCategory]!;
    } else {
      items = HealthSubcategoriesData.allHealthGoals;
    }

    return _buildItemsList(items, _selectedGoals, false);
  }

  Widget _buildItemsList(List<String> items, List<String> selected, bool isDisease) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.grey.shade300,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No items found',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selected.contains(item);
        final color = isDisease 
            ? Colors.red.shade400
            : AppColors.vitality;

        return GestureDetector(
          onTap: () => _handleToggle(item, isDisease),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? color.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? color.withOpacity(0.5)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.onyx,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIResultsList() {
    // Fix: Properly determine if displaying goals
    final isGoals = widget.showOnlyGoals || 
                    (!widget.showOnlyConditions && _tabController.index == 1);
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _aiResults.length,
      itemBuilder: (context, index) {
        final result = _aiResults[index];
        final isDisease = !isGoals;
        final selected = isDisease ? _selectedDiseases : _selectedGoals;
        final isSelected = selected.contains(result.item);

        Color cardColor;
        if (result.confidence >= 0.9) {
          cardColor = AppColors.vitality;
        } else if (result.confidence >= 0.7) {
          cardColor = Colors.blue.shade400;
        } else {
          cardColor = AppColors.slate;
        }

        return GestureDetector(
          onTap: () => _handleToggle(result.item, isDisease),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? cardColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? cardColor.withOpacity(0.5)
                    : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    result.matchIcon,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.item,
                        style: TextStyle(
                          color: isSelected ? cardColor : AppColors.onyx,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              result.confidencePercent,
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.explanation,
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? cardColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? cardColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.add,
                    color: isSelected
                        ? Colors.white
                        : AppColors.slate,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              widget.onDiseasesSelected(_selectedDiseases);
              widget.onGoalsSelected(_selectedGoals);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onyx,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              'SAVE (${_selectedDiseases.length + _selectedGoals.length} items)',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
