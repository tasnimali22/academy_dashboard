String? extractYoutubeId(String input) {
  final text = input.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(text)) return text;

  final uri = Uri.tryParse(text);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  final v = uri.queryParameters['v'];
  if (v != null && v.isNotEmpty) return v;

  final segs = uri.pathSegments;
  final i = segs.indexWhere((s) => ['shorts', 'embed', 'live'].contains(s));
  if (i != -1 && i + 1 < segs.length) return segs[i + 1];

  return null;
}