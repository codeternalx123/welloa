import 'package:equatable/equatable.dart';

class HormoneCascadeEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const HormoneCascadeEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
