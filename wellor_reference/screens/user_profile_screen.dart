import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../widgets/health_search_dialog.dart';
import '../widgets/feature_restriction_widgets.dart';
import '../theme/app_theme.dart';
import '../models/subscription_tier.dart';
import 'subscription_screen.dart';


/// UNICORN GRADE: The Biometric Identity Architect.
/// Features: Neural-Haptic Orchestration, Kinetic Mesh Backgrounds,
/// AI-Ready Life Stage Detection, and Gender-Intelligent Health Mapping.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  // Core Biometric Controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  
  // Selection State
  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedLifeStage;
  List<String> _selectedHealthGoals = [];
  List<String> _selectedDiseases = [];
  List<String> _selectedGenderNeeds = [];
  
  bool _isSaving = false;
  
  // Animation Orchestration
  late AnimationController _pulseController;
  late AnimationController _meshController;
  late Animation<double> _pulseAnimation;

  // ============================================
  // LIFE STAGE TAXONOMY - AI-Ready Classification
  // ============================================
  static const Map<String, Map<String, dynamic>> _lifeStages = {
    'teen': {
      'label': 'Teen (13-19)',
      'icon': Icons.school_rounded,
      'color': Color(0xFF8B5CF6),
      'description': 'Growth-focused nutrition',
    },
    'young_adult': {
      'label': 'Young Adult (20-35)',
      'icon': Icons.flash_on_rounded,
      'color': Color(0xFF3B82F6),
      'description': 'Peak performance & energy',
    },
    'adult': {
      'label': 'Adult (36-55)',
      'icon': Icons.balance_rounded,
      'color': Color(0xFF10B981),
      'description': 'Metabolic optimization',
    },
    'senior': {
      'label': 'Senior (55+)',
      'icon': Icons.self_improvement_rounded,
      'color': Color(0xFFEAB308),
      'description': 'Longevity & vitality',
    },
    'pregnancy': {
      'label': 'Pregnancy',
      'icon': Icons.pregnant_woman_rounded,
      'color': Color(0xFFEC4899),
      'description': 'Prenatal nutrition',
    },
    'nursing': {
      'label': 'Nursing',
      'icon': Icons.child_friendly_rounded,
      'color': Color(0xFFF97316),
      'description': 'Postnatal recovery',
    },
  };

  // ============================================
  // ACTIVITY LEVEL SPECTRUM - Clinical Precision
  // ============================================
  static const Map<String, Map<String, dynamic>> _activityLevels = {
    'sedentary': {
      'label': 'Sedentary',
      'icon': Icons.weekend_rounded,
      'color': Color(0xFF94A3B8),
      'description': 'Little to no exercise',
      'multiplier': 1.2,
    },
    'light': {
      'label': 'Light',
      'icon': Icons.directions_walk_rounded,
      'color': Color(0xFF22C55E),
      'description': '1-3 days/week',
      'multiplier': 1.375,
    },
    'moderate': {
      'label': 'Moderate',
      'icon': Icons.directions_run_rounded,
      'color': Color(0xFF3B82F6),
      'description': '3-5 days/week',
      'multiplier': 1.55,
    },
    'active': {
      'label': 'Active',
      'icon': Icons.fitness_center_rounded,
      'color': Color(0xFFF59E0B),
      'description': '6-7 days/week',
      'multiplier': 1.725,
    },
    'very_active': {
      'label': 'Athletic',
      'icon': Icons.sports_gymnastics_rounded,
      'color': Color(0xFFEF4444),
      'description': 'Intense daily training',
      'multiplier': 1.9,
    },
  };

  // ============================================
  // GENDER-SPECIFIC HEALTH NEEDS - Intelligent Mapping
  // ============================================
  static const Map<String, List<String>> _genderSpecificOptions = {
    'male': [
      'Prostate Health',
      'Testosterone Support',
      'Heart Health Focus',
      'Muscle Mass Priority',
      'Stress Management',
      'Hair Health',
      'Sexual Wellness',
      'Bone Density',
      'Athletic Performance',
      'Recovery Optimization',
    ],
    'female': [
      'Hormonal Balance',
      'Iron Optimization',
      'Bone Health (Osteoporosis Prevention)',
      'PCOS Management',
      'Menstrual Wellness',
      'Menopause Support',
      'Fertility Nutrition',
      'Skin & Hair Health',
      'Breast Health',
      'Thyroid Support',
      'Energy & Vitality',
      'Weight Management',
    ],
    'other': [
      'Hormonal Balance',
      'Bone Health',
      'Heart Health',
      'Mental Wellness',
      'Energy Optimization',
      'Stress Management',
      'Sleep Quality',
      'Immune Support',
      'Digestive Health',
      'Cognitive Function',
    ],
  };

  // ============================================
  // AI-POWERED FOCUS AREA RECOMMENDATION ENGINE
  // ============================================
  
  /// Calculates AI-recommended priority focus areas based on user's complete biometric profile
  List<String> _getAIRecommendedFocusAreas() {
    if (_selectedGender == null) return [];
    
    final allOptions = _genderSpecificOptions[_selectedGender] ?? [];
    final recommendations = <String>[];
    
    // Parse biometric data
    final age = int.tryParse(_ageController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;
    final bmi = height > 0 ? weight / ((height / 100) * (height / 100)) : 0;
    
    // 1. AGE-BASED RECOMMENDATIONS
    if (age > 0) {
      if (age >= 13 && age <= 19) {
        // Teens: Growth and development
        if (allOptions.contains('Bone Density')) recommendations.add('Bone Density');
        if (allOptions.contains('Energy & Vitality')) recommendations.add('Energy & Vitality');
        if (allOptions.contains('Athletic Performance')) recommendations.add('Athletic Performance');
      } else if (age >= 20 && age <= 35) {
        // Young adults: Peak performance
        if (allOptions.contains('Muscle Mass Priority')) recommendations.add('Muscle Mass Priority');
        if (allOptions.contains('Energy Optimization')) recommendations.add('Energy Optimization');
        if (allOptions.contains('Stress Management')) recommendations.add('Stress Management');
      } else if (age >= 36 && age <= 55) {
        // Adults: Metabolic health
        if (allOptions.contains('Heart Health Focus')) recommendations.add('Heart Health Focus');
        if (allOptions.contains('Weight Management')) recommendations.add('Weight Management');
        if (allOptions.contains('Hormonal Balance')) recommendations.add('Hormonal Balance');
      } else if (age > 55) {
        // Seniors: Longevity
        if (allOptions.contains('Bone Health (Osteoporosis Prevention)')) recommendations.add('Bone Health (Osteoporosis Prevention)');
        if (allOptions.contains('Heart Health')) recommendations.add('Heart Health');
        if (allOptions.contains('Cognitive Function')) recommendations.add('Cognitive Function');
        if (allOptions.contains('Prostate Health') && _selectedGender == 'male') recommendations.add('Prostate Health');
      }
    }
    
    // 2. LIFE STAGE SPECIFIC RECOMMENDATIONS
    if (_selectedLifeStage != null) {
      switch (_selectedLifeStage) {
        case 'teen':
          if (allOptions.contains('Bone Density')) recommendations.add('Bone Density');
          if (allOptions.contains('Energy & Vitality')) recommendations.add('Energy & Vitality');
          break;
        case 'young_adult':
          if (allOptions.contains('Athletic Performance')) recommendations.add('Athletic Performance');
          if (allOptions.contains('Stress Management')) recommendations.add('Stress Management');
          break;
        case 'adult':
          if (allOptions.contains('Heart Health Focus')) recommendations.add('Heart Health Focus');
          if (allOptions.contains('Weight Management')) recommendations.add('Weight Management');
          break;
        case 'senior':
          if (allOptions.contains('Bone Health (Osteoporosis Prevention)')) recommendations.add('Bone Health (Osteoporosis Prevention)');
          if (allOptions.contains('Cognitive Function')) recommendations.add('Cognitive Function');
          break;
        case 'pregnancy':
          if (allOptions.contains('Iron Optimization')) recommendations.add('Iron Optimization');
          if (allOptions.contains('Fertility Nutrition')) recommendations.add('Fertility Nutrition');
          if (allOptions.contains('Hormonal Balance')) recommendations.add('Hormonal Balance');
          break;
        case 'nursing':
          if (allOptions.contains('Iron Optimization')) recommendations.add('Iron Optimization');
          if (allOptions.contains('Energy & Vitality')) recommendations.add('Energy & Vitality');
          if (allOptions.contains('Hormonal Balance')) recommendations.add('Hormonal Balance');
          break;
      }
    }
    
    // 3. ACTIVITY LEVEL RECOMMENDATIONS
    if (_selectedActivityLevel != null) {
      switch (_selectedActivityLevel) {
        case 'sedentary':
          if (allOptions.contains('Energy Optimization')) recommendations.add('Energy Optimization');
          if (allOptions.contains('Heart Health Focus')) recommendations.add('Heart Health Focus');
          if (allOptions.contains('Weight Management')) recommendations.add('Weight Management');
          break;
        case 'light':
          if (allOptions.contains('Energy & Vitality')) recommendations.add('Energy & Vitality');
          if (allOptions.contains('Recovery Optimization')) recommendations.add('Recovery Optimization');
          break;
        case 'moderate':
          if (allOptions.contains('Recovery Optimization')) recommendations.add('Recovery Optimization');
          if (allOptions.contains('Muscle Mass Priority')) recommendations.add('Muscle Mass Priority');
          break;
        case 'active':
        case 'very_active':
          if (allOptions.contains('Athletic Performance')) recommendations.add('Athletic Performance');
          if (allOptions.contains('Recovery Optimization')) recommendations.add('Recovery Optimization');
          if (allOptions.contains('Muscle Mass Priority')) recommendations.add('Muscle Mass Priority');
          break;
      }
    }
    
    // 4. BMI-BASED RECOMMENDATIONS
    if (bmi > 0) {
      if (bmi < 18.5) {
        // Underweight
        if (allOptions.contains('Muscle Mass Priority')) recommendations.add('Muscle Mass Priority');
        if (allOptions.contains('Energy & Vitality')) recommendations.add('Energy & Vitality');
      } else if (bmi >= 25 && bmi < 30) {
        // Overweight
        if (allOptions.contains('Weight Management')) recommendations.add('Weight Management');
        if (allOptions.contains('Heart Health Focus')) recommendations.add('Heart Health Focus');
      } else if (bmi >= 30) {
        // Obese
        if (allOptions.contains('Weight Management')) recommendations.add('Weight Management');
        if (allOptions.contains('Heart Health Focus')) recommendations.add('Heart Health Focus');
        if (allOptions.contains('Heart Health')) recommendations.add('Heart Health');
      }
    }
    
    // 5. GENDER-SPECIFIC AGE CONSIDERATIONS
    if (_selectedGender == 'female' && age >= 45) {
      // Perimenopause/menopause support
      if (allOptions.contains('Menopause Support')) recommendations.add('Menopause Support');
      if (allOptions.contains('Bone Health (Osteoporosis Prevention)')) recommendations.add('Bone Health (Osteoporosis Prevention)');
    }
    
    if (_selectedGender == 'male' && age >= 50) {
      // Prostate health focus
      if (allOptions.contains('Prostate Health')) recommendations.add('Prostate Health');
    }
    
    // Remove duplicates and return top priority areas
    return recommendations.toSet().toList();
  }
  
  /// Checks if a focus area is AI-recommended based on user data
  bool _isAIRecommended(String option) {
    return _getAIRecommendedFocusAreas().contains(option);
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize Animation Controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _meshController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Load existing profile data
    final userProfile = context.read<UserProfileProvider>().userProfile;
    if (userProfile != null) {
      _weightController.text = userProfile.weight?.toString() ?? '';
      _heightController.text = userProfile.height?.toString() ?? '';
      _ageController.text = userProfile.age?.toString() ?? '';
      _selectedGender = userProfile.gender;
      _selectedActivityLevel = userProfile.activityLevel;
      _selectedLifeStage = userProfile.lifeStage;
      _selectedHealthGoals = List.from(userProfile.healthGoals);
      _selectedDiseases = List.from(userProfile.diseases);
      _selectedGenderNeeds = List.from(userProfile.genderSpecificNeeds);
    }
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _pulseController.dispose();
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.userProfile;

    // Initialize controllers if profile exists
    if (profile != null) {
      if (_weightController.text.isEmpty) _weightController.text = profile.weight?.toString() ?? '';
      if (_heightController.text.isEmpty) _heightController.text = profile.height?.toString() ?? '';
      if (_ageController.text.isEmpty) _ageController.text = profile.age?.toString() ?? '';
      if (_selectedGender == null) _selectedGender = profile.gender;
      if (_selectedActivityLevel == null) _selectedActivityLevel = profile.activityLevel;
      if (_selectedLifeStage == null) _selectedLifeStage = profile.lifeStage;
      if (_selectedHealthGoals.isEmpty) _selectedHealthGoals = List.from(profile.healthGoals);
      if (_selectedDiseases.isEmpty) _selectedDiseases = List.from(profile.diseases);
      if (_selectedGenderNeeds.isEmpty) _selectedGenderNeeds = List.from(profile.genderSpecificNeeds);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // 1. KINETIC MESH BACKGROUND (Light Theme)
          _buildKineticMeshBackground(),
          
          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSection(
                      icon: Icons.person_outline_rounded,
                      title: 'Core Biometrics',
                      child: _buildCoreBiometricsSection(),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: Icons.insights_rounded,
                      title: 'Lifestyle Factors',
                      child: _buildLifestyleSection(),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: Icons.favorite_border_rounded,
                      title: 'Health Goals',
                      subtitle: '${_selectedHealthGoals.length} selected',
                      onTap: () => _showHealthSearch(context, true),
                      child: _buildChipList(_selectedHealthGoals, AppColors.vitality, true),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: Icons.local_hospital_outlined,
                      title: 'Health Conditions',
                      subtitle: '${_selectedDiseases.length} selected',
                      onTap: () => _showHealthSearch(context, false),
                      child: _buildChipList(_selectedDiseases, Colors.red.shade400, false),
                    ),
                    if (_selectedGender != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        icon: _selectedGender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                        title: 'Gender-Specific Needs',
                        subtitle: '${_selectedGenderNeeds.length} selected',
                        onTap: () => _showGenderNeedsSelector(context),
                        child: _buildChipList(_selectedGenderNeeds, _selectedGender == 'male' ? Colors.blue.shade400 : Colors.pink.shade400, false),
                      ),
                    ],
                    // Premium Upgrade Section - Removed as requested
                    // const SizedBox(height: 24),
                    // _buildUpgradeSection(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildSaveButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar() {
    final subscription = context.watch<SubscriptionProvider>();
    final isFree = subscription.isFree;
    final tierLabel = isFree ? 'FREEMIUM' : (subscription.isPremium ? 'PREMIUM' : 'FREE');
    final tierColor = isFree ? const Color(0xFF64748B) : const Color(0xFF10B981);

    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.backgroundLight.withOpacity(0.8),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Health Profile',
              style: TextStyle(
                color: AppColors.onyx,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/subscription'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tierColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        background: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.slate),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.vitality, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onyx,
                  ),
                ),
              ),
              if (onTap != null)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.vitality.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 14, color: AppColors.vitality),
                        const SizedBox(width: 6),
                        Text(
                          subtitle ?? 'Edit',
                          style: const TextStyle(
                            color: AppColors.vitality,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildChipList(List<String> items, Color color, bool isGoal) {
    if (items.isEmpty) {
      return Text(
        isGoal ? 'Tap to add health goals.' : 'Tap to add conditions.',
        style: const TextStyle(color: AppColors.slate, fontStyle: FontStyle.italic),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Chip(
        label: Text(item),
        backgroundColor: color.withOpacity(0.1),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        side: BorderSide(color: color.withOpacity(0.2)),
        deleteIcon: Icon(Icons.close, size: 16, color: color),
        onDeleted: () {
          HapticFeedback.mediumImpact();
          setState(() {
            if (isGoal) {
              _selectedHealthGoals.remove(item);
            } else {
              _selectedDiseases.remove(item);
            }
          });
        },
      )).toList(),
    );
  }

  void _showHealthSearch(BuildContext context, bool isGoals) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => HealthSearchDialog(
        initialDiseases: _selectedDiseases,
        initialGoals: _selectedHealthGoals,
        onDiseasesSelected: (diseases) => setState(() => _selectedDiseases = diseases),
        onGoalsSelected: (goals) => setState(() => _selectedHealthGoals = goals),
        isGoalsTab: isGoals,
        showOnlyGoals: isGoals,
        showOnlyConditions: !isGoals,
      ),
    );
  }
  
  Widget _buildCoreBiometricsSection() {
    return Column(
      children: [
        _buildMetricField(_weightController, 'Weight', 'kg', Icons.fitness_center_rounded),
        const SizedBox(height: 16),
        _buildMetricField(_heightController, 'Height', 'cm', Icons.height_rounded),
        const SizedBox(height: 16),
        _buildMetricField(_ageController, 'Age', 'yrs', Icons.cake_rounded),
        const SizedBox(height: 16),
        _buildBMIIndicator(),
      ],
    );
  }

  Widget _buildLifestyleSection() {
    return Column(
      children: [
        _buildGenderSelector(),
        const SizedBox(height: 24),
        _buildLifeStageSelector(),
        const SizedBox(height: 24),
        _buildActivityLevelSelector(),
      ],
    );
  }

  Widget _buildUpgradeSection() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final currentTier = subscriptionProvider.subscription?.tier ?? SubscriptionTier.free;
        final isFree = currentTier == SubscriptionTier.free;

        if (isFree) {
          // Vibrant "Upgrade" CTA for free users
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.electric_bolt_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Unlock unlimited scans, AI & CGM',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Sleek "Upgrade Plan" section for premium users
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Dark slate color
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFFACC15), // Gold color
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upgrade Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFACC15).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentTier.name.toUpperCase()} PLAN',
                            style: const TextStyle(
                              color: Color(0xFFFACC15),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildMetricField(TextEditingController controller, String label, String unit, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onyx,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.slate),
        suffixText: unit,
        prefixIcon: Icon(icon, color: AppColors.slate),
        filled: true,
        fillColor: AppColors.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.vitality, width: 2),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBMIIndicator() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;
    final bmi = height > 0 ? weight / ((height / 100) * (height / 100)) : 0;
    
    String category = 'Enter data';
    Color categoryColor = AppColors.slate;
    
    if (bmi > 0) {
      if (bmi < 18.5) {
        category = 'Underweight';
        categoryColor = Colors.blue.shade400;
      } else if (bmi < 25) {
        category = 'Healthy';
        categoryColor = AppColors.vitality;
      } else if (bmi < 30) {
        category = 'Overweight';
        categoryColor = Colors.orange.shade400;
      } else {
        category = 'Obese';
        categoryColor = Colors.red.shade400;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Body Mass Index (BMI)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            bmi > 0 ? bmi.toStringAsFixed(1) : '--',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: categoryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Biological Sex', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGenderOption('male', 'Male', Icons.male_rounded, Colors.blue.shade400)),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderOption('female', 'Female', Icons.female_rounded, Colors.pink.shade300)),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderOption('other', 'Other', Icons.transgender_rounded, Colors.purple.shade300)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedGender = value;
          _selectedGenderNeeds.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.slate, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : AppColors.onyx,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifeStageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Life Stage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _lifeStages.keys.map((key) {
            final stage = _lifeStages[key]!;
            final isSelected = _selectedLifeStage == key;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedLifeStage = key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (stage['color'] as Color).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? (stage['color'] as Color) : Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stage['icon'], color: isSelected ? (stage['color'] as Color) : AppColors.slate, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      stage['label'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? (stage['color'] as Color) : AppColors.onyx,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivityLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activity Level', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate)),
        const SizedBox(height: 12),
        ..._activityLevels.keys.map((key) {
          final level = _activityLevels[key]!;
          final isSelected = _selectedActivityLevel == key;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedActivityLevel = key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? (level['color'] as Color).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? (level['color'] as Color) : Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(level['icon'], color: isSelected ? (level['color'] as Color) : AppColors.slate, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level['label'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? (level['color'] as Color) : AppColors.onyx,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          level['description'],
                          style: const TextStyle(fontSize: 11, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: (level['color'] as Color), size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showGenderNeedsSelector(BuildContext context) {
    final options = _genderSpecificOptions[_selectedGender] ?? [];
    if (options.isEmpty) return;

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Focus Areas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onyx),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI recommendations are highlighted with a star.',
                        style: TextStyle(fontSize: 14, color: AppColors.slate),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: options.map((option) {
                              final isSelected = _selectedGenderNeeds.contains(option);
                              final isRecommended = _isAIRecommended(option);
                              return GestureDetector(
                                onTap: () {
                                  modalState(() {
                                    if (isSelected) {
                                      _selectedGenderNeeds.remove(option);
                                    } else {
                                      _selectedGenderNeeds.add(option);
                                    }
                                  });
                                  setState(() {});
                                },
                                child: Chip(
                                  label: Text(option),
                                  avatar: isRecommended ? Icon(Icons.star_rounded, color: Colors.orange.shade600, size: 16) : null,
                                  backgroundColor: isSelected ? AppColors.vitality.withOpacity(0.1) : Colors.grey.shade100,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.vitality : AppColors.onyx,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.vitality.withOpacity(0.3) : Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vitality,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.onyx,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
          shadowColor: AppColors.onyx.withOpacity(0.4),
        ),
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2.0),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.save_alt_rounded, size: 20),
        label: Text(
          _isSaving ? 'SAVING...' : 'SAVE & CALIBRATE',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
    );
  }

  double _calculateCompleteness() {
    double completeness = 0;
    int totalFields = 6;
    
    if (_weightController.text.isNotEmpty) completeness += 1;
    if (_heightController.text.isNotEmpty) completeness += 1;
    if (_ageController.text.isNotEmpty) completeness += 1;
    if (_selectedGender != null) completeness += 1;
    if (_selectedActivityLevel != null) completeness += 1;
    if (_selectedLifeStage != null) completeness += 1;
    
    return completeness / totalFields;
  }
  
  void _saveProfile() async {
    if (_isSaving) return;
    
    final profileProvider = context.read<UserProfileProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    
    // For free users, allow partial profile saving to enable calibration with available data
    if (subscriptionProvider.isFree) {
      // Free users can save with any combination of fields - even if incomplete
      // This allows basic calibration to work with whatever data they provide
    } else {
      // Premium users must complete all fields for full functionality
      if (weight == null || height == null || age == null || _selectedGender == null || _selectedActivityLevel == null || _selectedLifeStage == null) {
        _showErrorDialog('Please complete all fields before saving.');
        return;
      }
    }
    
    setState(() { _isSaving = true; });
    
    final updatedProfile = UserProfile(
      weight: weight,
      height: height,
      age: age,
      gender: _selectedGender,
      activityLevel: _selectedActivityLevel,
      lifeStage: _selectedLifeStage,
      healthGoals: _selectedHealthGoals,
      diseases: _selectedDiseases,
      genderSpecificNeeds: _selectedGenderNeeds,
    );
    
    final success = await profileProvider.saveUserProfile(updatedProfile);
    
    if (!mounted) return;
    
    // Auto-sync nutrition goals from profile data (drives metabolic rings & scanner)
    if (success) {
      try {
        final nutritionProvider = context.read<NutritionGoalsProvider>();
        await nutritionProvider.syncGoalsFromProfile(updatedProfile);
      } catch (e) {
        debugPrint('\u{1F4CA} Goal sync after profile save: $e');
      }
    }
    
    if (!mounted) return;
    setState(() { _isSaving = false; });
    
    // Clear any stale subscription errors — free tier users should not be blocked
    if (subscriptionProvider.shouldShowSubscribePrompt) {
      subscriptionProvider.clearError();
    }
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health profile saved successfully!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } else {
      _showErrorDialog('Failed to save profile. Please try again.');
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================
  Widget _buildKineticMeshBackground() {
    return AnimatedBuilder(
      animation: _meshController,
      builder: (context, child) {
        return CustomPaint(
          painter: _KineticMeshPainter(
            animationValue: _meshController.value,
            color: AppColors.vitality.withOpacity(0.1),
          ),
          child: child,
        );
      },
      child: Container(),
    );
  }
}

class _KineticMeshPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _KineticMeshPainter({
    required this.animationValue,
    required this.color,
  }) : super(repaint: null);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final meshSize = 20;
    final waveHeight = 10 * math.sin(animationValue * math.pi * 2);

    for (double x = 0; x <= size.width; x += meshSize) {
      path.moveTo(x, 0);
      path.lineTo(x + meshSize, size.height);
      path.lineTo(x, size.height);
      path.lineTo(x - meshSize, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
