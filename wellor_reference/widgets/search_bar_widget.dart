import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import '../services/multi_ai_service.dart';
import '../widgets/feature_restriction_widgets.dart';

/// UNICORN UX: The Intelligence Nexus.
/// Features: Spatial Glassmorphism, Kinetic Triage, and Neural Haptic Feedback.
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  
  // Animation Suite
  late AnimationController _meshController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _meshController.dispose();
    _bounceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processNeuralQuery(String query) async {
    if (query.trim().isEmpty) return;

    if (!await recordAiInteractionAccess(context)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    // Neural Haptic Handshake
    HapticFeedback.mediumImpact();

    try {
      final prompt = _buildClinicalPrompt(query);
      final response = await MultiAIService().chatCompletion(prompt: prompt);

      if (mounted) {
        setState(() => _response = response);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() => _response = 'Nexus Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _buildClinicalPrompt(String query) => 
      '''You are Wellor Nexus - a high-intelligence, multilingual metabolic health orchestrator. 
      Respond in the SAME language as the query: $query. Be clinical yet encouraging.''';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. THE NEXUS INPUT
        ScaleTransition(
          scale: _bounceAnimation,
          child: _GlassmorphicContainer(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Interrogate Wellor AI...',
                hintStyle: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.5), fontSize: 14),
                prefixIcon: _buildNeuralAperture(),
                suffixIcon: _buildActionButton(),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              onSubmitted: _processNeuralQuery,
            ),
          ),
        ),

        // 2. SPATIAL RESPONSE ENGINE
        AnimatedSize(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          child: _response.isNotEmpty || _isLoading 
              ? _buildSpatialResponseArea() 
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildNeuralAperture() {
    return AnimatedBuilder(
      animation: _meshController,
      builder: (context, _) {
        return Transform.rotate(
          angle: _meshController.value * 2 * math.pi,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(Icons.hub_rounded, 
              color: _isLoading ? const Color(0xFF10B981) : const Color(0xFF4CAF50), 
              size: 20),
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () => _processNeuralQuery(_controller.text),
        onTapDown: (_) => _bounceController.forward(),
        onTapUp: (_) => _bounceController.reverse(),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF10B981)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildSpatialResponseArea() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: _GlassmorphicContainer(
        color: const Color(0xFFF8FAFC).withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) _buildThinkingIndicator(),
            if (_response.isNotEmpty) ...[
              const Text('NEXUS INSIGHT', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, color: Color(0xFF10B981))),
              const SizedBox(height: 8),
              Text(_response, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF1E293B))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Row(
      children: [
        const SizedBox(width: 4, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
        const SizedBox(width: 12),
        Text('SYNTHESIZING...', style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.8), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
      ],
    );
  }
}

// ============================================
// ATOMIC COMPONENTS: THE MOAT
// ============================================

class _GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _GlassmorphicContainer({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }
}