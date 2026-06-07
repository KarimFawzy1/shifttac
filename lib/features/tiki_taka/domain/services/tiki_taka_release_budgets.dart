/// Release size and latency budgets for Tiki-Taka v1 (Phase T12).
abstract final class TikiTakaReleaseBudgets {
  TikiTakaReleaseBudgets._();

  /// Shipped SQLite asset limit from [docs/dataset-plan.md] Phase D11.
  static const int maxBundledDatabaseBytes = 20 * 1024 * 1024;

  /// Attribute SVG bundle soft cap (clubs + leagues + nations).
  static const int maxAttributeSvgBytes = 8 * 1024 * 1024;

  /// Default board load via DAO on a warm local DB copy.
  static const Duration maxBoardLoadDuration = Duration(milliseconds: 750);

  /// Prefix player search on a warm local DB copy.
  static const Duration maxPlayerSearchDuration = Duration(milliseconds: 300);
}
