import 'package:equatable/equatable.dart';

class BehavioralContagionEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const BehavioralContagionEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
