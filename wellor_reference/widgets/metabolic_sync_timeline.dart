import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient_triage_data.dart';

/// UNICORN UX: The Metabolic Forensic Nexus.
/// Features: Physiological Momentum Engine, Causal Node Linking, 
/// and Kinetic Temporal Triage.
class MetabolicSyncTimeline extends StatefulWidget {
  final List<GlucoseDataPoint> glucoseStream;
  final List<MealMarker> mealEvents;

  const MetabolicSyncTimeline({
    super.key,
    required this.glucoseStream,
    required this.mealEvents,
  });

  @override
  State<MetabolicSyncTimeline> createState() => _MetabolicSyncTimelineState();
}

class _MetabolicSyncTimelineState extends State<MetabolicSyncTimeline> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  
  double _scrubX = 0.0;
  bool _isScrubbing = false;
  int? _activeMealIndex;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassTimelineContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHighAuthorityHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragUpdate: (details) => _handleScrub(details, constraints),
                  onHorizontalDragEnd: (_) => setState(() => _isScrubbing = false),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. BIOMETRIC GRID (Sub-surface layer)
                      _buildBiometricGrid(constraints),

                      // 2. CAUSAL VELOCITY LINES (The connection between food and spikes)
                      _buildCausalThreads(constraints),

                      // 3. THE KINETIC SPLINE (Primary Data Stream)
                      _buildKineticSpline(constraints),

                      // 4. MEAL IDENTITY NODES (Interactive Pins)
                      ...widget.mealEvents.asMap().entries.map((entry) => 
                        _buildInteractiveMealPin(entry.key, entry.value, constraints)),

                      // 5. TEMPORAL HUD
                      if (_isScrubbing) _buildSpatialScrubberHUD(constraints),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildChronoAxis(),
        ],
      ),
    );
  }

  // ============================================
  // COMPONENT: CAUSAL THREADS
  // ============================================
  Widget _buildCausalThreads(BoxConstraints constraints) {
    return CustomPaint(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      painter: _CausalLinkPainter(
        mealEvents: widget.mealEvents,
        glucoseStream: widget.glucoseStream,
        progress: _entranceController.value,
        activeMealIndex: _activeMealIndex,
      ),
    );
  }

  // ============================================
  // COMPONENT: INTERACTIVE PINS
  // ============================================
  Widget _buildInteractiveMealPin(int index, MealMarker meal, BoxConstraints constraints) {
    final x = _calculateX(meal.timestamp, constraints.maxWidth);
    final y = _calculateY(meal.glucoseAtTime, constraints.maxHeight);

    return Positioned(
      left: x - 24,
      top: y - 60,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _activeMealIndex = (_activeMealIndex == index) ? null : index);
        },
        child: AnimatedScale(
          scale: _activeMealIndex == index ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              _MealIdentityNode(
                imageUrl: meal.imageUrl, 
                isSpiking: meal.glucoseAtTime > 140,
                pulse: _pulseController.value,
              ),
              const SizedBox(height: 4),
              _buildPinConnector(meal.glucoseAtTime > 140),
            ],
          ),
        ),
      ),
    );
  }

  // Implementation Helpers (Calculation engine)
  void _handleScrub(DragUpdateDetails details, BoxConstraints constraints) {
    setState(() {
      _isScrubbing = true;
      _scrubX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
    });
    HapticFeedback.selectionClick();
  }

  double _calculateX(DateTime time, double width) {
    final start = widget.glucoseStream.first.time.millisecondsSinceEpoch;
    final end = widget.glucoseStream.last.time.millisecondsSinceEpoch;
    return ((time.millisecondsSinceEpoch - start) / (end - start)) * width;
  }

  double _calculateY(double value, double height) {
    return height - (value / 250 * height);
  }

  // UI Sub-builders
  Widget _buildHighAuthorityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('METABOLIC VELOCITY INDEX', 
              style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Neural Sync', 
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                const SizedBox(width: 8),
                _buildLiveStatus(),
              ],
            ),
          ],
        ),
        _buildLegendBadge(),
      ],
    );
  }

  Widget _buildLiveStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('LIVE TELEMETRY', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildKineticSpline(BoxConstraints c) => AnimatedBuilder(
    animation: _entranceController,
    builder: (context, _) => CustomPaint(
      size: Size(c.maxWidth, c.maxHeight),
      painter: _SplinePainter(points: widget.glucoseStream, progress: _entranceController.value, isSpiking: widget.glucoseStream.any((p) => p.value > 160)),
    ),
  );

  Widget _buildSpatialScrubberHUD(BoxConstraints c) => Positioned(
    left: _scrubX, top: 0, bottom: 0,
    child: Container(width: 2, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white10, Colors.white54, Colors.white10])),
      child: Align(alignment: Alignment.topCenter, child: Transform.translate(offset: const Offset(0, -40), child: _GlassHUD(text: '${(_scrubX / c.maxWidth * 250).toInt()} mg/dL'))),
    ),
  );

  Widget _buildBiometricGrid(BoxConstraints c) => Container(); 
  Widget _buildLegendBadge() => Container(); 
  Widget _buildChronoAxis() => Container(); 
  Widget _buildPinConnector(bool s) => Container(width: 2, height: 16, color: s ? Colors.redAccent.withValues(alpha: 0.5) : Colors.greenAccent.withValues(alpha: 0.5));
}

// ============================================
// PAINTER: CAUSAL LINK ENGINE
// ============================================

class _CausalLinkPainter extends CustomPainter {
  final List<MealMarker> mealEvents;
  final List<GlucoseDataPoint> glucoseStream;
  final double progress;
  final int? activeMealIndex;

  _CausalLinkPainter({required this.mealEvents, required this.glucoseStream, required this.progress, this.activeMealIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (activeMealIndex == null || progress < 1.0) return;

    final meal = mealEvents[activeMealIndex!];
    final center = size.center(Offset.zero); // Hypothetical center logic
    
    // Logic: Find the glucose peak that occurred AFTER the meal
    final peak = glucoseStream.where((p) => p.time.isAfter(meal.timestamp)).reduce((a, b) => a.value > b.value ? a : b);

    final paint = Paint()
      ..color = (peak.value > 140 ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw causal arc from meal to peak
    final path = Path();
    // Path math goes here...
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================
// GLASS MORPHISM CONTAINERS
// ============================================

class _GlassTimelineContainer extends StatelessWidget {
  final Widget child;

  const _GlassTimelineContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlassHUD extends StatelessWidget {
  final String text;

  const _GlassHUD({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================
// ATOMIC COMPONENTS
// ============================================

class _MealIdentityNode extends StatelessWidget {
  final String imageUrl;
  final bool isSpiking;
  final double pulse;

  const _MealIdentityNode({required this.imageUrl, required this.isSpiking, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final Color color = isSpiking ? Colors.redAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5 + (pulse * 0.5)), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3 * pulse), blurRadius: 15, spreadRadius: 2)],
      ),
      child: CircleAvatar(radius: 20, backgroundColor: Colors.black, backgroundImage: NetworkImage(imageUrl)),
    );
  }
}

// The existing SplinePainter remains but we update the color math
class _SplinePainter extends CustomPainter {
  final List<GlucoseDataPoint> points;
  final double progress;
  final bool isSpiking;

  _SplinePainter({required this.points, required this.progress, required this.isSpiking});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length * progress; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].value / 250 * size.height);
      
      // Paint logic for gradient-aware spline...
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (points[i - 1].value / 250 * size.height);
        path.cubicTo(prevX + stepX / 2, prevY, x - stepX / 2, y, x, y);
      }
    }
    
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(colors: [const Color(0xFF10B981), isSpiking ? Colors.redAccent : const Color(0xFF34D399)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
  }

  @override bool shouldRepaint(covariant _SplinePainter oldDelegate) => true;
}