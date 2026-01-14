enum OrderStatus {
  pending('Offen'),
  inProgress('In Bearbeitung'),
  ready('Fertig'),
  served('Serviert'),
  cancelled('Storniert');

  final String label;
  const OrderStatus(this.label);

  factory OrderStatus.fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => OrderStatus.pending,
    );
  }

  String toShortString() => name;

  /// Nächster Status im Workflow (Koch-Perspektive)
  OrderStatus? get nextStatus => switch (this) {
    OrderStatus.pending => OrderStatus.inProgress,
    OrderStatus.inProgress => OrderStatus.ready,
    OrderStatus.ready => null,
    OrderStatus.served => null,
    OrderStatus.cancelled => null,
  };

  /// Welche Rollen dürfen Status ändern?
  bool canChangeBy(String role) => switch (this) {
    OrderStatus.pending => ['Koch', 'Inhaber'].contains(role),
    OrderStatus.inProgress => ['Koch', 'Inhaber'].contains(role),
    OrderStatus.ready => ['Kellner', 'Barkeeper', 'Inhaber'].contains(role),
    OrderStatus.served => ['Kellner', 'Barkeeper', 'Inhaber'].contains(role),
    OrderStatus.cancelled => [
      'Koch',
      'Kellner',
      'Barkeeper',
      'Inhaber',
    ].contains(role),
  };
}

