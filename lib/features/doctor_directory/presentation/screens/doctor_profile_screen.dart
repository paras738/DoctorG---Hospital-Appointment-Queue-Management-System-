import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../controllers/doctor_directory_controller.dart';
import '../../domain/models/doctor_model.dart';
import '../../domain/models/doctor_review_model.dart';

class DoctorProfileScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(doctorProfileProvider(doctorId));
    final reviewsAsync = ref.watch(doctorReviewsProvider(doctorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile link copied to clipboard'),
                ),
              );
            },
          ),
        ],
      ),
      body: doctorAsync.when(
        data: (doctor) {
          if (doctor == null) {
            return const Center(child: Text('Doctor profile not found'));
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Header Card
                    _buildDoctorHeader(doctor),
                    const SizedBox(height: 16),

                    // Quick Stats Row
                    _buildStatsRow(doctor),
                    const SizedBox(height: 20),

                    // About / Bio
                    if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
                      const Text(
                        'About Doctor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doctor.bio!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Hospital & Clinic Location Card
                    _buildHospitalCard(doctor),
                    const SizedBox(height: 20),

                    // Next Slot Preview
                    _buildNextSlotCard(doctor),
                    const SizedBox(height: 20),

                    // Verified Patient Reviews
                    _buildReviewsSection(reviewsAsync),
                  ],
                ),
              ),

              // Bottom Sticky Booking Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consultation Fee',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '₹${doctor.consultationFee.round()}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDarkTeal,
                            ),
                          ),
                        ],
                      ),
                      FilledButton(
                        onPressed: () => context.push('/booking/${doctor.id}'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }

  Widget _buildDoctorHeader(DoctorModel doctor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppTheme.primaryLightTeal,
          backgroundImage: doctor.photoUrl != null
              ? NetworkImage(doctor.photoUrl!)
              : null,
          child: doctor.photoUrl == null
              ? const Icon(Icons.person, size: 40, color: AppTheme.primaryTeal)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doctor.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (doctor.isVerified)
                    const Icon(
                      Icons.verified,
                      color: AppTheme.primaryTeal,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                doctor.specialization,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.secondaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reg No: ${doctor.registrationNumber}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              // Bayesian Rating Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB300)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFE65100),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          doctor.avgRating > 0
                              ? doctor.avgRating.toStringAsFixed(1)
                              : 'New',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        if (doctor.reviewCount > 0) ...[
                          const SizedBox(width: 2),
                          Text(
                            '(${doctor.reviewCount})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (doctor.isTopRated) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLightTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TOP RATED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(DoctorModel doctor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Experience', '${doctor.experienceYears} Yrs'),
          _buildStatDivider(),
          _buildStatItem('Avg Consult', '${doctor.avgConsultationMinutes} Min'),
          _buildStatDivider(),
          _buildStatItem('Languages', doctor.languages.take(2).join(', ')),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 28, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildHospitalCard(DoctorModel doctor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 20,
                color: AppTheme.primaryTeal,
              ),
              SizedBox(width: 8),
              Text(
                'Affiliated Clinic / Hospital',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            doctor.hospitalName ?? 'Manipal Hospital, Bengaluru',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            doctor.hospitalAddress ??
                'HAL Old Airport Rd, Kodihalli, Bengaluru',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (doctor.distanceMeters != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.near_me,
                  size: 14,
                  color: AppTheme.secondaryBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  '${DistanceCalculator.formatDistance(doctor.distanceMeters!)} from your location',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextSlotCard(DoctorModel doctor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLightTeal.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppTheme.primaryDarkTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Available Slot',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryDarkTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.nextAvailableSlot != null
                      ? 'Today, ${doctor.nextAvailableSlot!.hour}:${doctor.nextAvailableSlot!.minute.toString().padLeft(2, '0')}'
                      : 'Today, 11:30 AM (Walk-in or online token)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(
    AsyncValue<List<DoctorReviewModel>> reviewsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verified Patient Reviews',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Reviews are permitted only after an appointment is marked completed.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No reviews yet. Be the first to consult and review!',
                ),
              );
            }
            return Column(
              children: reviews.map((r) => _buildReviewCard(r)).toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => Text('Could not load reviews: $err'),
        ),
      ],
    );
  }

  Widget _buildReviewCard(DoctorReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    review.patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppTheme.primaryTeal,
                  ),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: index < review.rating
                        ? const Color(0xFFFFB300)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.3,
              ),
            ),
          ],
          if (review.doctorReply != null && review.doctorReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: AppTheme.secondaryBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Doctor Reply',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.doctorReply!,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
