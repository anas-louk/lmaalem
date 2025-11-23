import 'package:flutter/material.dart';
import '../../data/models/employee_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../components/indrive_card.dart';

/// Widget de carte employé inspiré d'InDrive
class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback? onTap;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InDriveCard(
      margin: const EdgeInsets.only(bottom: 16),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: employee.image != null
                ? Image.network(
                    employee.image!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderAvatar(),
                  )
                : _placeholderAvatar(),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.nomComplet,
                  style: AppTextStyles.h4.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  employee.competence,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      employee.ville,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (employee.disponibilite ? AppColors.secondary : AppColors.error)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        employee.disponibilite ? 'Disponible' : 'Indisponible',
                        style: AppTextStyles.caption.copyWith(
                          color: employee.disponibilite ? AppColors.secondary : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 76,
      height: 76,
      color: AppColors.greyLight,
      child: const Icon(Icons.person_outline, size: 32, color: AppColors.textSecondary),
    );
  }
}

