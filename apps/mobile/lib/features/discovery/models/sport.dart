enum Sport { tennis, running }

extension SportApi on Sport {
  String get apiValue => this == Sport.tennis ? 'TENNIS' : 'RUNNING';
  String get label => this == Sport.tennis ? 'Tenis' : 'Correr';

  static Sport fromApi(String v) {
    switch (v) {
      case 'TENNIS':
        return Sport.tennis;
      case 'RUNNING':
        return Sport.running;
      default:
        return Sport.tennis;
    }
  }
}
