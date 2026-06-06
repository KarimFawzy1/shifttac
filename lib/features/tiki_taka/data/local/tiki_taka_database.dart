import 'package:sqflite/sqflite.dart';

/// Read-only access to the bundled Tiki-Taka SQLite database.
///
/// G5 provides the contract and stub only. Phase T1 implements copy-on-first-use,
/// fingerprint invalidation, and read-only open per
/// [docs/tiki-taka-database-contract.md].
abstract class TikiTakaDatabase {
  /// Opens or reuses the app-local read-only database copy.
  Future<void> open();

  /// Closes the active connection if open.
  Future<void> close();

  /// Whether [database] is available.
  bool get isOpen;

  /// Active read-only connection. Throws if not [isOpen].
  Database get database;
}

/// Placeholder implementation for Gap G5. Replaced in Phase T1.
class TikiTakaDatabaseStub implements TikiTakaDatabase {
  @override
  bool get isOpen => false;

  @override
  Database get database {
    throw StateError(
      'TikiTakaDatabase is not open. Call open() after Phase T1 implementation.',
    );
  }

  @override
  Future<void> open() {
    throw UnimplementedError(
      'TikiTakaDatabase.open() is implemented in Phase T1.',
    );
  }

  @override
  Future<void> close() async {}
}
