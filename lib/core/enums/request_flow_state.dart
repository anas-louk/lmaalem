/// États possibles du flux de traitement d'une demande côté client
enum RequestFlowState {
  idle,
  pending,
  accepted,
  completed,
  canceled,
}

extension RequestFlowStateX on RequestFlowState {
  String get value => name;

  bool get locksNavigation =>
      this == RequestFlowState.pending || this == RequestFlowState.accepted;

  static RequestFlowState fromValue(String? value) {
    switch (value) {
      case 'pending':
        return RequestFlowState.pending;
      case 'accepted':
        return RequestFlowState.accepted;
      case 'completed':
        return RequestFlowState.completed;
      case 'canceled':
        return RequestFlowState.canceled;
      default:
        return RequestFlowState.idle;
    }
  }

  static RequestFlowState fromLegacyStatut(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return RequestFlowState.pending;
      case 'accepted':
        return RequestFlowState.accepted;
      case 'completed':
        return RequestFlowState.completed;
      case 'cancelled':
      case 'canceled':
        return RequestFlowState.canceled;
      default:
        return RequestFlowState.idle;
    }
  }
}

