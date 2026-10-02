import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/feature_restriction_widgets.dart';
import '../models/family_plan_models.dart';

class FamilyProfileScreen extends StatefulWidget {
  const FamilyProfileScreen({super.key});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _religionController = TextEditingController();
  final _countryController = TextEditingController();
  final _familyDescriptionController = TextEditingController();
  final _flavorController = TextEditingController();

  int _familySize = 1;
  List<String> _flavorPreferences = [];
  List<FamilyMember> _familyMembers = [];

  final List<String> _religions = [
    'Christianity',
    'Islam',
    'Hinduism',
    'Buddhism',
    'Judaism',
    'Sikhism',
    'Other',
    'None'
  ];

  final List<String> _countries = [
    'Kenya',
    'Tanzania',
    'Uganda',
    'Rwanda',
    'Burundi',
    'Ethiopia',
    'South Africa',
    'Nigeria',
    'Ghana',
    'Other'
  ];

  final List<String> _flavorOptions = [
    'Spicy',
    'Sweet',
    'Sour',
    'Salty',
    'Umami',
    'Bitter',
    'Mild',
    'Herbal',
    'Citrusy',
    'Smoky'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() {
    final profileProvider = context.read<FamilyProfileProvider>();
    final profile = profileProvider.familyPlanSetup;

    if (profile != null) {
      _religionController.text = profile.preferredCuisine;
      _countryController.text = profile.budgetCurrency;
      _familyDescriptionController.text = profile.cookingSkillLevel;
      _familySize = profile.familySize;
      _flavorPreferences = profile.sharedAllergies;
      _familyMembers = List.from(profile.members);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Profile'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Consumer<FamilyProfileProvider>(
        builder: (context, profileProvider, child) {
          return profileProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Basic Information'),
                        _buildDropdownField(
                          'Religion',
                          _religionController,
                          _religions,
                          Icons.church,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          'Country',
                          _countryController,
                          _countries,
                          Icons.location_on,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Family Description',
                          _familyDescriptionController,
                          'Describe your family\'s eating habits, preferences, etc.',
                          Icons.family_restroom,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Family Size & Preferences'),
                        _buildFamilySizeSelector(),
                        const SizedBox(height: 16),
                        _buildFlavorPreferences(),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Family Members & Health Goals'),
                        _buildFamilyMembersSection(),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save Family Profile',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, TextEditingController controller, List<String> options, IconData icon) {
    return DropdownButtonFormField<String>(
      initialValue: controller.text.isNotEmpty ? controller.text : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          controller.text = value ?? '';
        });
      },
      validator: (value) => value?.isEmpty ?? true ? 'Please select $label' : null,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Please enter $label' : null,
    );
  }

  Widget _buildFamilySizeSelector() {
    final maxMembers = context.watch<SubscriptionProvider>().maxFamilyMembers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Family Size (max $maxMembers)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (_familySize > 1) {
                  setState(() => _familySize--);
                  _updateFamilyMembers();
                }
              },
              icon: const Icon(Icons.remove_circle, color: Color(0xFF4CAF50)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4CAF50)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_familySize',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () {
                if (_familySize < maxMembers) {
                  setState(() => _familySize++);
                  _updateFamilyMembers();
                }
              },
              icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlavorPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flavor Preferences',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _flavorOptions.map((flavor) {
            final isSelected = _flavorPreferences.contains(flavor);
            return FilterChip(
              label: Text(flavor),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _flavorPreferences.add(flavor);
                  } else {
                    _flavorPreferences.remove(flavor);
                  }
                });
              },
              selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF4CAF50),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFamilyMembersSection() {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _familyMembers.length,
          itemBuilder: (context, index) {
            return _buildFamilyMemberCard(index);
          },
        ),
        if (_familyMembers.length < _familySize)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              onPressed: _addFamilyMember,
              icon: const Icon(Icons.add),
              label: const Text('Add Family Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFamilyMemberCard(int index) {
    final member = _familyMembers[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Member ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeFamilyMember(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: member.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (value) {
                _familyMembers[index] = FamilyMember(
                  id: member.id,
                  name: value,
                  age: member.age,
                  gender: member.gender,
                  healthGoals: member.healthGoals,
                  diseases: member.diseases,
                  allergies: member.allergies,
                  preferredFlavor: member.preferredFlavor,
                  dietType: member.dietType,
                  activityLevel: member.activityLevel,
                  targetWeight: member.targetWeight,
                );
              },
              validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: member.age.toString(),
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _familyMembers[index] = FamilyMember(
                  id: member.id,
                  name: member.name,
                  age: int.tryParse(value) ?? 0,
                  gender: member.gender,
                  healthGoals: member.healthGoals,
                  diseases: member.diseases,
                  allergies: member.allergies,
                  preferredFlavor: member.preferredFlavor,
                  dietType: member.dietType,
                  activityLevel: member.activityLevel,
                  targetWeight: member.targetWeight,
                );
              },
              validator: (value) => value?.isEmpty ?? true ? 'Please enter age' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: member.healthGoals.join(', '),
              decoration: const InputDecoration(
                labelText: 'Health Goals',
                prefixIcon: Icon(Icons.health_and_safety),
                hintText: 'e.g., Weight loss, muscle gain, diabetes management',
              ),
              maxLines: 2,
              onChanged: (value) {
                _familyMembers[index] = FamilyMember(
                  id: member.id,
                  name: member.name,
                  age: member.age,
                  gender: member.gender,
                  healthGoals: value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  diseases: member.diseases,
                  allergies: member.allergies,
                  preferredFlavor: member.preferredFlavor,
                  dietType: member.dietType,
                  activityLevel: member.activityLevel,
                  targetWeight: member.targetWeight,
                );
              },
              validator: (value) => value?.isEmpty ?? true ? 'Please enter health goals' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: member.allergies.join(', '),
              decoration: const InputDecoration(
                labelText: 'Dietary Restrictions (Optional)',
                prefixIcon: Icon(Icons.restaurant),
                hintText: 'e.g., Vegetarian, gluten-free, nut allergy',
              ),
              onChanged: (value) {
                _familyMembers[index] = FamilyMember(
                  id: member.id,
                  name: member.name,
                  age: member.age,
                  gender: member.gender,
                  healthGoals: member.healthGoals,
                  diseases: member.diseases,
                  allergies: value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  preferredFlavor: member.preferredFlavor,
                  dietType: member.dietType,
                  activityLevel: member.activityLevel,
                  targetWeight: member.targetWeight,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateFamilyMembers() {
    if (_familyMembers.length > _familySize) {
      _familyMembers = _familyMembers.sublist(0, _familySize);
    }
  }

  void _addFamilyMember() {
    if (_familyMembers.length < _familySize) {
      setState(() {
        _familyMembers.add(FamilyMember(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '',
          age: 0,
          gender: 'Other',
          healthGoals: [],
          diseases: [],
          allergies: [],
        ));
      });
    }
  }

  void _removeFamilyMember(int index) {
    setState(() {
      _familyMembers.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_familyMembers.length != _familySize) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add details for all family members')),
      );
      return;
    }

    final profile = FamilyPlanSetup(
      familySize: _familySize,
      members: _familyMembers,
      monthlyBudget: 10000.0, // Default budget, can be customized
      budgetCurrency: _countryController.text.isNotEmpty ? _countryController.text : 'KES',
      sharedAllergies: _flavorPreferences,
      preferredCuisine: _religionController.text.isNotEmpty ? _religionController.text : 'Mixed',
      cookingSkillLevel: _familyDescriptionController.text.isNotEmpty ? _familyDescriptionController.text : 'Intermediate',
      mealsPerDay: 3,
    );

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid;
    
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Check subscription before saving
    final subProvider = context.read<SubscriptionProvider>();
    if (!subProvider.canAccessFamilyProfiles) {
      if (!mounted) return;
      FeatureRestrictionDialog.show(
        context,
        featureName: 'Family Profiles',
        featureDescription:
            'Premium supports up to 7 family members; Ultra supports up to 10. Upgrade to create shared meal plans and health dashboards.',
        icon: Icons.family_restroom_rounded,
      );
      return;
    }

    if (_familySize > subProvider.maxFamilyMembers) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your plan allows up to ${subProvider.maxFamilyMembers} family members.',
          ),
        ),
      );
      return;
    }

    try {
      await context.read<FamilyProfileProvider>().saveFamilyPlanSetup(userId, profile);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family profile saved successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('permission') || errorMsg.contains('denied') || errorMsg.contains('unauthorized')) {
        FeatureRestrictionDialog.show(
          context,
          featureName: 'Family Profiles',
          featureDescription: 'Upgrade to the Family plan to save and manage family profiles.',
          icon: Icons.family_restroom_rounded,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _religionController.dispose();
    _countryController.dispose();
    _familyDescriptionController.dispose();
    _flavorController.dispose();
    super.dispose();
  }
}