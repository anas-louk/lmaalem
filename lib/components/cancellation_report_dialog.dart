import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'indrive_button.dart';
import 'custom_text_field.dart';

/// Dialogue pour collecter le rapport d'annulation du client
class CancellationReportDialog extends StatefulWidget {
  final String requestId;
  final String? employeeName;
  final Function(String reason) onConfirm;

  const CancellationReportDialog({
    super.key,
    required this.requestId,
    this.employeeName,
    required this.onConfirm,
  });

  @override
  State<CancellationReportDialog> createState() => _CancellationReportDialogState();
}

class _CancellationReportDialogState extends State<CancellationReportDialog> {
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
            color: AppColors.error.withOpacity(0.3),
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
                      color: AppColors.error.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Titre
                Center(
                  child: Text(
                    'cancel_request_report_title'.tr,
                    style: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                if (widget.employeeName != null)
                  Center(
                    child: Text(
                      'cancel_request_report_message'.tr.replaceAll('{employee}', widget.employeeName!),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                // Champ de texte pour la raison
                CustomTextField(
                  controller: _reasonController,
                  hint: 'cancel_request_reason_hint'.tr,
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
                      label: _isSubmitting ? 'submitting'.tr : 'confirm_cancellation'.tr,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      variant: InDriveButtonVariant.ghost,
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

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      widget.onConfirm(_reasonController.text.trim());
    }
  }
}

