import 'web_url_clean_stub.dart' if (dart.library.html) 'web_url_clean_web.dart' as impl;

void cleanBrowserQuery() => impl.cleanBrowserQuery();

bool openExternalUrl(String url) => impl.openExternalUrl(url);
