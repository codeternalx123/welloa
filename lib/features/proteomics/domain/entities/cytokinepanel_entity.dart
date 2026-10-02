import 'package:equatable/equatable.dart';

class CytokinePanelEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const CytokinePanelEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
