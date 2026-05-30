import 'dart:js_interop';

@JS('loadGoogleMapsWithKey')
external void _loadGoogleMapsWithKey(String apiKey);

void loadGoogleMapsApi(String apiKey) {
  try {
    _loadGoogleMapsWithKey(apiKey);
  } catch (e) {
    // ignore
  }
}
