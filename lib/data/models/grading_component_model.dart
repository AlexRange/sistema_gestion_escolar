class GradingComponent {
  final String id; // UUID único
  final String name; // 'Asistencia', 'Actividades', 'Examen', 'Participación'
  final double weight; // 0.10 = 10%, 0.60 = 60%, etc.
  final String type; // 'attendance' | 'activities' | 'evaluation' | 'custom'

  const GradingComponent({
    required this.id,
    required this.name,
    required this.weight,
    required this.type,
  });

  // Peso como porcentaje legible
  String get weightLabel => '${(weight * 100).toStringAsFixed(0)}%';

  // Puntos máximos que vale este componente (sobre 100)
  double get maxPoints => weight * 100;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'weight': weight,
        'type': type,
      };

  factory GradingComponent.fromMap(Map<String, dynamic> d) => GradingComponent(
        id: d['id'] ?? '',
        name: d['name'] ?? '',
        weight: (d['weight'] as num).toDouble(),
        type: d['type'] ?? 'custom',
      );

  GradingComponent copyWith({
    String? name,
    double? weight,
    String? type,
  }) =>
      GradingComponent(
        id: id,
        name: name ?? this.name,
        weight: weight ?? this.weight,
        type: type ?? this.type,
      );

  // Componentes por defecto (el sistema actual)
  static List<GradingComponent> get defaults => [
        const GradingComponent(
          id: 'attendance',
          name: 'Asistencia',
          weight: 0.10,
          type: 'attendance',
        ),
        const GradingComponent(
          id: 'activities',
          name: 'Actividades',
          weight: 0.60,
          type: 'activities',
        ),
        const GradingComponent(
          id: 'evaluation',
          name: 'Examen / Proyecto',
          weight: 0.30,
          type: 'evaluation',
        ),
      ];
}
