/// Web implementation — uses dart:html beforeunload event.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Single shared listener so we can detach it cleanly.
html.EventListener? _listener;

void setUnloadGuard({required bool enabled}) {
  if (enabled) {
    // Already armed — nothing to do.
    if (_listener != null) return;
    _listener = (html.Event e) {
      // Cast so we can call preventDefault + set returnValue.
      final be = e as html.BeforeUnloadEvent;
      // Modern browsers show their own generic message and ignore custom text,
      // but both preventDefault + a non-empty returnValue are still required
      // to trigger the prompt across Chrome/Safari/Firefox.
      be.preventDefault();
      be.returnValue = 'You have unsaved progress in AIWire — leave anyway?';
    };
    html.window.addEventListener('beforeunload', _listener);
  } else {
    if (_listener == null) return;
    html.window.removeEventListener('beforeunload', _listener);
    _listener = null;
  }
}
