/// Mints the id for a new entity — the library's one seam for identity.
///
/// **An id is opaque.** The library stores, returns and compares an id, and
/// never parses it, sorts on it, or does arithmetic on it. The default
/// (newMeta with no generator) is a random UUID v4; pass one to the use cases
/// that mint ids internally.
typedef IdGenerator = String Function();
