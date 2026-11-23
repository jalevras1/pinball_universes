/// Pointer-drag charge mapping with deliberate-release protection.
/// A down/up tap without a meaningful pull never launches a ball.
class PlungerModel {
  PlungerModel({this.fullPullPixels = 110, this.minimumPullPixels = 8})
    : assert(fullPullPixels > 0),
      assert(minimumPullPixels > 0),
      assert(minimumPullPixels < fullPullPixels);

  final double fullPullPixels;
  final double minimumPullPixels;
  double _pullPixels = 0;

  double get charge => (_pullPixels / fullPullPixels).clamp(0, 1).toDouble();
  bool get isArmed => _pullPixels >= minimumPullPixels;

  void pull(double downwardPixels) {
    if (!downwardPixels.isFinite) {
      _pullPixels = 0;
      return;
    }
    _pullPixels = downwardPixels.clamp(0.0, fullPullPixels).toDouble();
  }

  /// Returns power in [0, 1], or null if released without a valid pull.
  double? release() {
    final power = isArmed ? charge : null;
    cancel();
    return power;
  }

  void cancel() => _pullPixels = 0;
}
