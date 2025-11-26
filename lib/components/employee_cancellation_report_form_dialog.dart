import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'indrive_button.dart';
import 'custom_text_field.dart';

/// Dialogue pour que l'employé remplisse son rapport d'annulation
class EmployeeCancellationReportFormDialog extends StatefulWidget {
  final String requestId;
  final String? clientName;
  final String? clientReason;
  final Future<void> Function(String employeeReason) onConfirm;

  const EmployeeCancellationReportFormDialog({
    super.key,
    required this.requestId,
    this.clientName,
    this.clientReason,
    required this.onConfirm,
  });

  @override
  State<EmployeeCancellationReportFormDialog> createState() => _EmployeeCancellationReportFormDialogState();
}

class _EmployeeCancellationReportFormDialogState extends State<EmployeeCancellationReportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.warning.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Icône
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.report_outlined,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Titre
                Center(
                  child: Text(
                    'request_cancelled_by_client'.tr,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                if (widget.clientName != null)
                  Center(
                    child: Text(
                      'employee_cancellation_report_message'.tr.replaceAll('{client}', widget.clientName!),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                // Raison du client (si disponible)
                if (widget.clientReason != null && widget.clientReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.nightSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white10,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'client_cancellation_reason'.tr,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.clientReason!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Champ de texte pour la raison de l'employé
                CustomTextField(
                  controller: _reasonController,
                  hint: 'employee_cancellation_reason_hint'.tr,
                  maxLines: 4,
                  fillColor: AppColors.nightSecondary,
                  textColor: Colors.white,
                  labelColor: Colors.white,
                  hintColor: Colors.white54,
                  iconColor: Colors.white70,
                  borderColor: Colors.white10,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'reason_required'.tr;
                    }
                    if (value.trim().length < 10) {
                      return 'reason_min_length'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Boutons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InDriveButton(
                      label: _isSubmitting ? 'submitting'.tr : 'submit_report'.tr,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      variant: InDriveButtonVariant.primary,
                    ),
                    const SizedBox(height: 12),
                    InDriveButton(
                      label: 'cancel'.tr,
                      onPressed: _isSubmitting ? null : () => Get.back(),
                      variant: InDriveButtonVariant.ghost,
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      
      try {
        // Call the callback
        await widget.onConfirm(_reasonController.text.trim());
        
        // Close the dialog after successful submission
        if (mounted) {
          Get.back();
        }
      } catch (e) {
        // If there's an error, reset submitting state
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        // Optionally show error message
        debugPrint('Error submitting report: $e');
      }
    }
  }
}

