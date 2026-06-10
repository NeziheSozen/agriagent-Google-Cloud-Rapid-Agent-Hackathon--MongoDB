class PlotDraft {
  String name;
  double sizeHectares;
  String irrigationLevel;
  List<String> crops;

  PlotDraft({
    this.name = 'Ana Tarla',
    this.sizeHectares = 20.0,
    this.irrigationLevel = 'Medium',
    List<String>? crops,
  }) : crops = crops ?? ['Tomato'];

  Map<String, dynamic> toJson() => {
        'name': name,
        'size_hectares': sizeHectares,
        'irrigation_level': irrigationLevel,
        'tenure_type': 'Owned',
        'crop_history': [], // Default empty history for new plots
      };
}
