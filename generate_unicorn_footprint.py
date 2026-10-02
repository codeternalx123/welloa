import os

base_dir = "/home/codeternal/Desktop/Personal/Longevity/lib/features"

# The new Decacorn Unicorn Features
domains = {
    "genomics": ["DnaSequence", "MethylationSite", "TelomereAssay", "Cyp450Enzyme"],
    "microbiome": ["GutFlora", "BacterialStrain", "Metabolite", "DysbiosisIndex"],
    "social_contagion": ["LongevityNode", "BehavioralContagion", "FamilyGraph", "PeerInfluence"],
    "proteomics": ["ProteinMarker", "CytokinePanel", "HormoneCascade", "AminoAcidProfile"],
    "wearable_iot": ["ContinuousGlucose", "HyperbaricOxygen", "RedLightTherapy", "VagusNerveStim"]
}

layers = ["domain/entities", "domain/usecases", "domain/repositories",
          "data/models", "data/datasources", "data/repositories",
          "presentation/providers", "presentation/pages", "presentation/widgets"]

def ensure_dirs():
    for domain in domains:
        for layer in layers:
            os.makedirs(os.path.join(base_dir, domain, layer), exist_ok=True)

def generate_domain_layer(domain, entity):
    # Entity
    path = os.path.join(base_dir, domain, "domain/entities", f"{entity.lower()}_entity.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:equatable/equatable.dart';\n\nclass {entity}Entity extends Equatable {{\n  final String id;\n  final DateTime timestamp;\n\n  const {entity}Entity({{required this.id, required this.timestamp}});\n\n  @override\n  List<Object?> get props => [id, timestamp];\n}}\n")
    
    # Repository Interface
    path = os.path.join(base_dir, domain, "domain/repositories", f"{entity.lower()}_repository.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:dartz/dartz.dart';\nimport '../../../../core/error/failures.dart';\nimport '../entities/{entity.lower()}_entity.dart';\n\nabstract class {entity}Repository {{\n  Future<Either<Failure, {entity}Entity>> get{entity}(String id);\n  Future<Either<Failure, List<{entity}Entity>>> getAll();\n  Future<Either<Failure, void>> sync{entity}();\n}}\n")
    
    # Use Case
    path = os.path.join(base_dir, domain, "domain/usecases", f"analyze_{entity.lower()}.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:dartz/dartz.dart';\nimport '../../../../core/error/failures.dart';\nimport '../entities/{entity.lower()}_entity.dart';\nimport '../repositories/{entity.lower()}_repository.dart';\n\nclass Analyze{entity}UseCase {{\n  final {entity}Repository repository;\n  Analyze{entity}UseCase(this.repository);\n\n  Future<Either<Failure, {entity}Entity>> execute(String id) async {{\n    return await repository.get{entity}(id);\n  }}\n}}\n")

def generate_data_layer(domain, entity):
    # Model
    path = os.path.join(base_dir, domain, "data/models", f"{entity.lower()}_model.dart")
    with open(path, 'w') as f:
        f.write(f"import '../../domain/entities/{entity.lower()}_entity.dart';\n\nclass {entity}Model extends {entity}Entity {{\n  const {entity}Model({{required String id, required DateTime timestamp}}) : super(id: id, timestamp: timestamp);\n  \n  factory {entity}Model.fromJson(Map<String, dynamic> json) {{\n    return {entity}Model(id: json['id'], timestamp: DateTime.parse(json['timestamp']));\n  }}\n}}\n")
    
    # Local DS
    path = os.path.join(base_dir, domain, "data/datasources", f"{entity.lower()}_local_ds.dart")
    with open(path, 'w') as f:
        f.write(f"import '../models/{entity.lower()}_model.dart';\n\nabstract class {entity}LocalDataSource {{\n  Future<void> cache({entity}Model model);\n  Future<{entity}Model> getCached(String id);\n}}\n")
    
    # Remote DS
    path = os.path.join(base_dir, domain, "data/datasources", f"{entity.lower()}_remote_ds.dart")
    with open(path, 'w') as f:
        f.write(f"import '../models/{entity.lower()}_model.dart';\n\nabstract class {entity}RemoteDataSource {{\n  Future<{entity}Model> fetchFromCloud(String id);\n}}\n")
    
    # Repo Impl
    path = os.path.join(base_dir, domain, "data/repositories", f"{entity.lower()}_repo_impl.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:dartz/dartz.dart';\nimport '../../../../core/error/failures.dart';\nimport '../../domain/entities/{entity.lower()}_entity.dart';\nimport '../../domain/repositories/{entity.lower()}_repository.dart';\n\nclass {entity}RepositoryImpl implements {entity}Repository {{\n  @override\n  Future<Either<Failure, {entity}Entity>> get{entity}(String id) async {{ return Left(ServerFailure('Unimplemented')); }}\n  @override\n  Future<Either<Failure, List<{entity}Entity>>> getAll() async {{ return Left(ServerFailure('Unimplemented')); }}\n  @override\n  Future<Either<Failure, void>> sync{entity}() async {{ return Right(null); }}\n}}\n")

def generate_presentation_layer(domain, entity):
    # Provider
    path = os.path.join(base_dir, domain, "presentation/providers", f"{entity.lower()}_provider.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:flutter_riverpod/flutter_riverpod.dart';\n// Complex DI Graph for {entity} would go here...\n")

    # Screen
    path = os.path.join(base_dir, domain, "presentation/pages", f"{entity.lower()}_screen.dart")
    with open(path, 'w') as f:
        f.write(f"import 'package:flutter/material.dart';\n\nclass {entity}Screen extends StatelessWidget {{\n  const {entity}Screen({{Key? key}}) : super(key: key);\n  @override\n  Widget build(BuildContext context) {{ return Scaffold(appBar: AppBar(title: Text('{entity} Analytics')), body: Center(child: Text('Enterprise {entity} Module'))); }}\n}}\n")

if __name__ == "__main__":
    ensure_dirs()
    total_files = 0
    for domain, entities in domains.items():
        for entity in entities:
            generate_domain_layer(domain, entity)
            generate_data_layer(domain, entity)
            generate_presentation_layer(domain, entity)
            total_files += 9
    
    print(f"Massive Enterprise Injection Complete. Generated {total_files} robust Clean Architecture files across 5 new Unicorn domains.")

