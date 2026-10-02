import 'package:equatable/equatable.dart';

class MethylationSiteEntity extends Equatable {
  final String id;
  final DateTime timestamp;

  const MethylationSiteEntity({required this.id, required this.timestamp});

  @override
  List<Object?> get props => [id, timestamp];
}
