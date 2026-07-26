class SurveyPoint {
  const SurveyPoint({
    required this.id,
    required this.northing,
    required this.easting,
    required this.elevation,
    required this.description,
  });

  final String id;
  final double northing;
  final double easting;
  final double elevation;
  final String description;

  String get elevText => elevation.toStringAsFixed(2);
  String get northingText => northing.toStringAsFixed(3);
  String get eastingText => easting.toStringAsFixed(3);

  SurveyPoint copyWith({
    String? id,
    double? northing,
    double? easting,
    double? elevation,
    String? description,
  }) {
    return SurveyPoint(
      id: id ?? this.id,
      northing: northing ?? this.northing,
      easting: easting ?? this.easting,
      elevation: elevation ?? this.elevation,
      description: description ?? this.description,
    );
  }
}
