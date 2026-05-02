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
  }) : lastUpdatedAt = lastUpdatedAt ?? createdAt;

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
  };

  factory PasswordEntry.fromMap(Map<String, dynamic> map) => PasswordEntry(
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
  );
}
