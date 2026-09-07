/// A user-defined label that can be attached to one or more vault entries.
///
/// [color] is stored as a hex ARGB integer (e.g. 0xFF4CAF50).
class Tag {
  final int? id;
  final String name;
  final int color;

  const Tag({this.id, required this.name, required this.color});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'color': color,
  };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
    id: map['id'] as int?,
    name: map['name'] as String,
    color: map['color'] as int,
  );

  Tag copyWith({int? id, String? name, int? color}) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
