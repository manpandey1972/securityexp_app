/// Opaque pagination cursor for chat message queries.
///
/// This abstraction hides the underlying Firestore [DocumentSnapshot]
/// from the repository interface, enabling non-Firestore backends.
///
/// Consumers should treat this as an opaque token — pass it back to
/// [IChatMessageRepository.loadOlderMessages] without inspecting internals.
class PaginationCursor {
  /// The underlying cursor data. Type is intentionally `dynamic` to avoid
  /// leaking Firestore types into the domain/interface layer.
  final dynamic _cursor;

  /// Creates a [PaginationCursor] wrapping an implementation-specific cursor.
  const PaginationCursor(this._cursor);

  /// Retrieve the underlying cursor, cast to [T].
  ///
  /// This is intended for repository *implementations* only — not consumers.
  T as<T>() => _cursor as T;

  /// Whether the cursor is valid (non-null underlying data).
  bool get isValid => _cursor != null;
}
