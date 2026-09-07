class PasswordEntry {
  final int? id;
  final String category;
  final String name;
  final String url;
  final String username;
  final String password;
  final String? pin;
  final String? packageName;
  final String? appIconBase64;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final bool isFavorite;

  /// IDs of the [Tag]s attached to this entry.
  /// Populated by [PasswordRepository] via the entry_tags junction table —
  /// not stored directly inside the passwords row.
  final List<int> tagIds;

  const PasswordEntry({
    this.id,
    required this.category,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.pin,
    this.packageName,
    this.appIconBase64,
    required this.createdAt,
    DateTime? lastUpdatedAt,
    this.isFavorite = false,
    List<int>? tagIds,
  }) : lastUpdatedAt = lastUpdatedAt ?? createdAt,
       tagIds = tagIds ?? const [];

  /// Serialises the passwords-table columns only (tagIds is managed via the
  /// entry_tags junction table and is NOT included here).
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'category': category,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'pin': pin,
    'package_name': packageName,
    'app_icon_base64': appIconBase64,
    'created_at': createdAt.toIso8601String(),
    'last_updated_at': lastUpdatedAt.toIso8601String(),
    'is_favorite': isFavorite ? 1 : 0,
  };

  factory PasswordEntry.fromMap(
    Map<String, dynamic> map, {
    List<int>? tagIds,
  }) => PasswordEntry(
    id: map['id'] as int?,
    category: map['category'] as String,
    name: map['name'] as String,
    url: map['url'] as String,
    username: map['username'] as String,
    password: map['password'] as String,
    pin: map['pin'] as String?,
    packageName: map['package_name'] as String?,
    appIconBase64: map['app_icon_base64'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    lastUpdatedAt: map['last_updated_at'] != null
        ? DateTime.parse(map['last_updated_at'] as String)
        : DateTime.parse(map['created_at'] as String),
    isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    tagIds: tagIds ?? const [],
  );

  PasswordEntry copyWith({
    int? id,
    String? category,
    String? name,
    String? url,
    String? username,
    String? password,
    String? pin,
    String? packageName,
    String? appIconBase64,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    bool? isFavorite,
    List<int>? tagIds,
  }) => PasswordEntry(
    id: id ?? this.id,
    category: category ?? this.category,
    name: name ?? this.name,
    url: url ?? this.url,
    username: username ?? this.username,
    password: password ?? this.password,
    pin: pin ?? this.pin,
    packageName: packageName ?? this.packageName,
    appIconBase64: appIconBase64 ?? this.appIconBase64,
    createdAt: createdAt ?? this.createdAt,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    tagIds: tagIds ?? this.tagIds,
  );
}
