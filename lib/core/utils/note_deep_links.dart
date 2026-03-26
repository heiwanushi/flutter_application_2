Uri buildNoteDeepLink(String noteId) {
  return Uri(scheme: 'notesapp', host: 'note', pathSegments: [noteId]);
}

String? extractNoteIdFromDeepLink(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != 'notesapp') return null;
  if (uri.host != 'note') return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.first;
}
