class Contact {
  final String name;
  final String phoneNumber;
  final String? avatar;

  Contact({
    required this.name,
    required this.phoneNumber,
    this.avatar,
  });

  String get initials {
    if (name.isEmpty) return '?';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
