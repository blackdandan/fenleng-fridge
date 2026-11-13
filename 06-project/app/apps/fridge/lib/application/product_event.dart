typedef ProductEvent =
    void Function(String name, Map<String, String> properties);

/// Analytics must never turn a committed local action into a business failure.
void emitProductEvent(
  ProductEvent? sink,
  String name,
  Map<String, String> properties,
) {
  try {
    sink?.call(name, properties);
  } catch (_) {
    /* No raw payload logging. */
  }
}
