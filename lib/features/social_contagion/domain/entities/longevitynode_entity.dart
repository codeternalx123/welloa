import 'package:equatable/equatable.dart';

class LongevityNodeEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const LongevityNodeEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
