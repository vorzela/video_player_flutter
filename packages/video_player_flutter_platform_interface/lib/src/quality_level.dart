class QualityLevel {
  const QualityLevel({
    required this.index,
    required this.height,
    required this.bitrate,
    required this.label,
  });

  final int index;
  final int height;
  final int bitrate;
  final String label;

  Map<String, Object?> toMap() => {
        'index': index,
        'height': height,
        'bitrate': bitrate,
        'label': label,
      };

  factory QualityLevel.fromMap(Map<Object?, Object?> map) => QualityLevel(
        index: (map['index'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        bitrate: (map['bitrate'] as num?)?.toInt() ?? 0,
        label: '${map['label'] ?? ''}',
      );

  @override
  bool operator ==(Object other) =>
      other is QualityLevel &&
      other.index == index &&
      other.height == height &&
      other.bitrate == bitrate &&
      other.label == label;

  @override
  int get hashCode => Object.hash(index, height, bitrate, label);
}
