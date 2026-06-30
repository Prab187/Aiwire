/// Cross-platform `beforeunload` guard for Flutter web.
///
/// On web, calling [setUnloadGuard]`(true)` makes the browser show its native
/// "Are you sure you want to leave?" prompt if the user tries to close the
/// tab, hit refresh, or navigate away. Pass `false` to clear the guard.
///
/// On mobile/desktop this is a no-op (you can't refresh a Flutter app there).
///
/// Implementation uses conditional imports so the dart:html dependency only
/// loads on web.
import 'web_unload_guard_stub.dart'
    if (dart.library.html) 'web_unload_guard_web.dart' as impl;

void setUnloadGuard({required bool enabled}) =>
    impl.setUnloadGuard(enabled: enabled);
