// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void cleanBrowserQuery() {
  html.window.history.replaceState(null, '', html.window.location.pathname);
}

/// Full-page redirect — most reliable on Flutter web for PayMongo.
bool openExternalUrl(String url) {
  html.window.location.href = url;
  return true;
}
