import 'package:equatable/equatable.dart';

class Cyp450EnzymeEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const Cyp450EnzymeEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
