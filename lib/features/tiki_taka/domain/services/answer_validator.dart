import '../../data/local/daos/validation_dao.dart';
import '../../data/local/tiki_player_id.dart';
import '../../data/models/tiki_player_search_result.dart';

/// Why an answer was rejected by [AnswerValidator].
enum AnswerValidationReason {
  playerNotMatching,
  duplicatePlayer,
}

/// Result of validating a player guess for one board cell.
class AnswerValidationResult {
  const AnswerValidationResult._({
    required this.isValid,
    this.reason,
    this.player,
  });

  const AnswerValidationResult.valid(TikiPlayerSearchResult player)
    : this._(isValid: true, player: player);

  const AnswerValidationResult.invalid(AnswerValidationReason reason)
    : this._(isValid: false, reason: reason);

  final bool isValid;
  final AnswerValidationReason? reason;
  final TikiPlayerSearchResult? player;
}

/// Validates guesses against DAO rules and duplicate-player policy.
class AnswerValidator {
  AnswerValidator(this._validationDao);

  final ValidationDao _validationDao;

  Future<AnswerValidationResult> validate({
    required String playerId,
    required String rowAttributeId,
    required String colAttributeId,
    required Set<String> usedPlayerIds,
  }) async {
    final normalizedId = toTmPlayerId(playerId);
    final match = await _validationDao.validatePlayer(
      playerId: normalizedId,
      rowAttributeId: rowAttributeId,
      colAttributeId: colAttributeId,
    );

    if (usedPlayerIds.contains(normalizedId)) {
      if (match != null) {
        return const AnswerValidationResult.invalid(
          AnswerValidationReason.duplicatePlayer,
        );
      }
      return const AnswerValidationResult.invalid(
        AnswerValidationReason.playerNotMatching,
      );
    }

    if (match == null) {
      return const AnswerValidationResult.invalid(
        AnswerValidationReason.playerNotMatching,
      );
    }

    return AnswerValidationResult.valid(match);
  }
}
