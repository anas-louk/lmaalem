import 'package:flutter/material.dart';
import 'employee_cancellation_report_form_dialog.dart';

/// Dialogue pour afficher le rapport d'annulation à l'employé (obsolète - remplacé par EmployeeCancellationReportFormDialog)
/// Gardé pour compatibilité
class EmployeeCancellationReportDialog extends StatelessWidget {
  final String requestId;
  final String? clientName;
  final String? cancellationReason;
  final VoidCallback onClose;

  const EmployeeCancellationReportDialog({
    super.key,
    required this.requestId,
    this.clientName,
    this.cancellationReason,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Rediriger vers le formulaire
    return EmployeeCancellationReportFormDialog(
      requestId: requestId,
      clientName: clientName,
      clientReason: cancellationReason,
      onConfirm: (employeeReason) async {
        onClose();
      },
    );
  }
}

