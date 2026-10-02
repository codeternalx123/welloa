import 'package:equatable/equatable.dart';

class DysbiosisIndexEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const DysbiosisIndexEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
