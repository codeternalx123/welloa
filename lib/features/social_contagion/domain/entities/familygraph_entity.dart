import 'package:equatable/equatable.dart';

class FamilyGraphEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const FamilyGraphEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
