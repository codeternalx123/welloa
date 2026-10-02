import 'package:equatable/equatable.dart';

class GutFloraEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const GutFloraEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
