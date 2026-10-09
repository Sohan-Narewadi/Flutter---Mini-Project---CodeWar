/// Languages the server-side judge can run. (C++ is intentionally absent.)
enum Language {
  python('python', 'Python 3', 'py'),
  typescript('typescript', 'TypeScript', 'ts');

  const Language(this.id, this.label, this.ext);

  final String id;
  final String label;
  final String ext;

  static Language fromId(String id) => Language.values.firstWhere(
    (l) => l.id == id,
    orElse: () => Language.python,
  );
}
