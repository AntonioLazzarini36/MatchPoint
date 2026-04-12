enum SwipeType { like, pass }

extension SwipeTypeApi on SwipeType {
  String get apiValue => this == SwipeType.like ? 'LIKE' : 'PASS';
}
