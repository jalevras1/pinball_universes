/// Repeatable in-game diagnostic scenarios. Add a case here and a handler in
/// PinballGame.runDeveloperScenario when new hardware needs phone playtesting.
enum PinballDeveloperScenario {
  weakLaunch('5% REARM'),
  skillLaunch('17% SKILL'),
  mediumLaunch('60% LAUNCH'),
  fullLaunch('100% LAUNCH'),
  leftFlipper('LEFT FLIPPER'),
  rightFlipper('RIGHT FLIPPER'),
  bumperContact('BUMPER CONTACT'),
  drain('DRAIN / REARM'),
  resetRound('RESET ROUND');

  const PinballDeveloperScenario(this.label);

  final String label;
}
