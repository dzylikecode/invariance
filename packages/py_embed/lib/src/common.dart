class const Version(final int major, final int minor, final int patch) {
  factory Version.parse(
    String text, {
    String delimiter = '.',
    bool strict = false,
  }) {
    final pattern = RegExp(
      <String>[
        if (strict) '^',
        r'(\d+)',
        RegExp.escape(delimiter),
        r'(\d+)',
        RegExp.escape(delimiter),
        r'(\d+)',
        if (strict) r'$',
      ].join(),
    );

    final version = pattern.firstMatch(text);

    if (version == null) {
      throw FormatException('Invalid version string: $text');
    }

    return Version(
      .parse(version.group(1)!),
      .parse(version.group(2)!),
      .parse(version.group(3)!),
    );
  }

  String format({String delimiter = '.'}) =>
      '$major$delimiter$minor$delimiter$patch';

  @override
  String toString() => format();
}
