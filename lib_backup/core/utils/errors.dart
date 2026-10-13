/// Turns whatever a provider caught into the plain sentence a user should
/// see. `Exception('x').toString()` is `'Exception: x'` - fine in a debug
/// log, not fine in a red banner someone has to read and act on. Every
/// provider's `catch (e) { _error = e.toString(); }` should instead read
/// `_error = friendlyError(e);` so a validation message, a network
/// failure or anything else all come out the same way: just the message.
String friendlyError(Object error) {
  final String raw = error.toString();

  const String prefix = 'Exception: ';

  if (raw.startsWith(prefix)) {
    return raw.substring(prefix.length);
  }

  return raw;
}
