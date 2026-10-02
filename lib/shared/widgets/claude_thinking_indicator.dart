import 'package:flutter/material.dart';

class ClaudeThinkingIndicator extends StatelessWidget {
  final String? message;

  const ClaudeThinkingIndicator({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology, color: Color(0xFF00F5FF)),
          const SizedBox(width: 12),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00F5FF),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message ?? 'Claude is analyzing your biological data...',
              style: const TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
