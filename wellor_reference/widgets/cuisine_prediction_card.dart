// lib/widgets/cuisine_prediction_card.dart
// UNICORN GRADE: Cuisine Prediction Visualization
// Shows 4-strategy ensemble predictions with beautiful UI

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_cuisine_learning_agent.dart';
import '../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════
/// CUISINE PREDICTION CARD
/// ═══════════════════════════════════════════════════════════════════
/// 
/// Beautiful visualization of glycemic predictions for cultural foods
/// Shows 4-strategy ensemble with confidence indicators
/// 
/// Features:
/// - Animated confidence meter
/// - Strategy breakdown visualization
/// - Neural-haptic feedback
/// - Learning contribution UI
/// ═══════════════════════════════════════════════════════════════════

class CuisinePredictionCard extends StatefulWidget {
  final MealGlycemicPrediction prediction;
  final String mealName;
  final VoidCallback? onRecordActual;
  final bool showStrategyBreakdown;
  
  const CuisinePredictionCard({
    super.key,
    required this.prediction,
    required this.mealName,
    this.onRecordActual,
    this.showStrategyBreakdown = true,
  });

  @override
  State<CuisinePredictionCard> createState() => _CuisinePredictionCardState();
}

class _CuisinePredictionCardState extends State<CuisinePredictionCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Haptic feedback on load
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.vitality.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.vitality.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildMainPrediction(),
          if (widget.showStrategyBreakdown) _buildStrategyBreakdown(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.vitality.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.vitality.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '🍽️',
              style: TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mealName,
                  style: const TextStyle(
                    color: AppColors.onyx,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vitality,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Predicted',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.prediction.sources.length} sources',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            widget.prediction.confidenceEmoji,
            style: const TextStyle(fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPrediction() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Glucose spike prediction
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '+${widget.prediction.predictedSpikeGlucose.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _getSpikeColor(),
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'mg/dL',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Confidence meter
          _buildConfidenceMeter(),
          
          const SizedBox(height: 16),
          
          // Explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.slate,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.prediction.explanation,
                    style: const TextStyle(
                      color: AppColors.onyx,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Timing info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimingChip(
                icon: Icons.schedule,
                label: 'Peak Time',
                value: '${widget.prediction.peakTime.inMinutes} min',
              ),
              _buildTimingChip(
                icon: Icons.trending_up,
                label: 'Impact Level',
                value: _getImpactLevel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceMeter() {
    final confidence = widget.prediction.confidence / 100;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Confidence',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.prediction.confidence.toStringAsFixed(0)}% ${widget.prediction.confidenceLevel}',
              style: TextStyle(
                color: _getConfidenceColor(),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: confidence,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getConfidenceColor(),
                        _getConfidenceColor().withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _getConfidenceColor().withOpacity(
                          0.3 + (_pulseController.value * 0.2),
                        ),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStrategyBreakdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.vitality.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.vitality.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showDetails = !_showDetails);
            },
            child: Row(
              children: [
                const Text(
                  'Strategy Breakdown',
                  style: TextStyle(
                    color: AppColors.onyx,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.slate,
                ),
              ],
            ),
          ),
          if (_showDetails) ...[
            const SizedBox(height: 16),
            _buildStrategyBar(
              icon: '📊',
              label: 'Personal History',
              weight: widget.prediction.personalWeight,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStrategyBar(
              icon: '🌍',
              label: 'Regional Database',
              weight: widget.prediction.regionalWeight,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildStrategyBar(
              icon: '🤖',
              label: 'AI Vision',
              weight: widget.prediction.aiWeight,
              color: Colors.purple,
            ),
            const SizedBox(height: 8),
            _buildStrategyBar(
              icon: '👥',
              label: 'Community Learning',
              weight: widget.prediction.communityWeight,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStrategyBar({
    required String icon,
    required String label,
    required double weight,
    required Color color,
  }) {
    final isActive = weight > 0;
    
    return Row(
      children: [
        Text(
          icon,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black.withOpacity(isActive ? 1.0 : 0.3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.onyx : AppColors.slate,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: isActive ? weight : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isActive ? '${(weight * 100).toStringAsFixed(0)}%' : '-',
          style: TextStyle(
            color: isActive ? color : AppColors.slate,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Record actual button
          if (widget.onRecordActual != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.onRecordActual?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.vitality,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Record Actual Impact',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Info text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: AppColors.slate,
              ),
              const SizedBox(width: 6),
              Text(
                'Recording helps improve future predictions',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimingChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.slate),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onyx,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpikeColor() {
    final spike = widget.prediction.predictedSpikeGlucose;
    if (spike < 30) return Colors.green;
    if (spike < 50) return Colors.lightGreen;
    if (spike < 70) return Colors.orange;
    return Colors.red.shade400;
  }

  Color _getConfidenceColor() {
    final confidence = widget.prediction.confidence;
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.blue;
    if (confidence >= 40) return Colors.orange;
    return Colors.red.shade400;
  }

  String _getImpactLevel() {
    final spike = widget.prediction.predictedSpikeGlucose;
    if (spike < 30) return 'Low';
    if (spike < 50) return 'Moderate';
    if (spike < 70) return 'High';
    return 'Very High';
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// CUISINE PREDICTION DIALOG
/// ═══════════════════════════════════════════════════════════════════

class CuisinePredictionDialog extends StatelessWidget {
  final MealGlycemicPrediction prediction;
  final String mealName;
  final VoidCallback? onRecordActual;
  
  const CuisinePredictionDialog({
    super.key,
    required this.prediction,
    required this.mealName,
    this.onRecordActual,
  });
  
  static Future<void> show({
    required BuildContext context,
    required MealGlycemicPrediction prediction,
    required String mealName,
    VoidCallback? onRecordActual,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CuisinePredictionDialog(
        prediction: prediction,
        mealName: mealName,
        onRecordActual: onRecordActual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CuisinePredictionCard(
              prediction: prediction,
              mealName: mealName,
              onRecordActual: () {
                Navigator.pop(context);
                onRecordActual?.call();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
