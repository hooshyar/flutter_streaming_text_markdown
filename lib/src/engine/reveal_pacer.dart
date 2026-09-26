/// Decides how many units a [RevealScheduler] should reveal on a single
/// tick, given the current backlog (source length minus cursor, in UTF-16
/// code units).
abstract class RevealPacer {
  /// Const constructor for subclasses.
  const RevealPacer();

  /// Number of [RevealEngine.step] calls to make this tick. Must be `>= 0`.
  int unitsThisTick(int backlogUnits);
}

/// The only pacer that ships in Phase A: always reveals exactly one unit
/// per tick, regardless of backlog. A backlog-proportional pacer is a
/// Phase B seam (see [RevealPacer]).
class FixedPacer extends RevealPacer {
  /// Creates a fixed, one-unit-per-tick pacer.
  const FixedPacer();

  @override
  int unitsThisTick(int backlogUnits) => 1;
}
