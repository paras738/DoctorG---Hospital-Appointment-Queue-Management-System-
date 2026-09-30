import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../domain/models/doctor_model.dart';

class DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onTap,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: doctor.isTopRated
              ? const Color(0xFFFFD700).withOpacity(0.6)
              : Colors.grey.shade200,
          width: doctor.isTopRated ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Details + Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor Avatar with Available Now Green Indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppTheme.primaryLightTeal,
                        backgroundImage: doctor.photoUrl != null
                            ? NetworkImage(doctor.photoUrl!)
                            : null,
                        child: doctor.photoUrl == null
                            ? Text(
                                doctor.fullName.split(' ').length > 1
                                    ? '${doctor.fullName.split(' ')[0][0]}${doctor.fullName.split(' ')[1][0]}'
                                    : 'Dr',
                                style: const TextStyle(
                                  color: AppTheme.primaryDarkTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      if (doctor.isAvailableNow)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Doctor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + Top Rated Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                doctor.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (doctor.isTopRated) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFFB300),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      size: 13,
                                      color: Color(0xFFE65100),
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'TOP RATED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Specialization & Experience
                        Text(
                          '${doctor.specialization} • ${doctor.experienceYears} yrs exp',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Hospital Name & Straight-Line Distance
                        if (doctor.hospitalName != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppTheme.secondaryBlue,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  doctor.hospitalName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (doctor.distanceMeters != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  DistanceCalculator.formatDistance(
                                    doctor.distanceMeters!,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 10),

              // Bottom Row: Rating + Fee + Book Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bayesian Rating
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: Color(0xFFFFB300),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doctor.avgRating > 0
                            ? doctor.avgRating.toStringAsFixed(1)
                            : 'New',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (doctor.reviewCount > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '(${doctor.reviewCount})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Fee
                  Text(
                    '₹${doctor.consultationFee.round()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDarkTeal,
                    ),
                  ),

                  // Action Button
                  FilledButton(
                    onPressed: onBook,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      minimumSize: const Size(90, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Book', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
