import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../doctor_directory/domain/models/doctor_model.dart';
import '../../../reviews/domain/models/review_report_model.dart';
import '../controllers/admin_controller.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unverifiedAsync = ref.watch(unverifiedDoctorsListProvider);
    final flaggedAsync = ref.watch(flaggedReviewsListProvider);
    final adminController = ref.read(adminControllerProvider.notifier);

    final unverifiedCount = unverifiedAsync.valueOrNull?.length ?? 0;
    final flaggedCount = flaggedAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DoctorG Admin Panel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Medical Verification & Moderation',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Doctor Approvals ($unverifiedCount)'),
            Tab(text: 'Flagged Reviews ($flaggedCount)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Doctor Approvals
          unverifiedAsync.when(
            data: (doctors) =>
                _buildDoctorsApprovalTab(context, doctors, adminController),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
            error: (err, _) =>
                Center(child: Text('Error loading doctors: $err')),
          ),

          // Tab 2: Flagged Reviews
          flaggedAsync.when(
            data: (reports) =>
                _buildFlaggedReviewsTab(context, reports, adminController),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
            error: (err, _) =>
                Center(child: Text('Error loading flagged reports: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsApprovalTab(
    BuildContext context,
    List<DoctorModel> doctors,
    AdminController controller,
  ) {
    if (doctors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 56,
                color: AppTheme.successGreen,
              ),
              SizedBox(height: 12),
              Text(
                'All Doctors Verified!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'No pending medical council license verifications.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = doctors[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primaryLightTeal,
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primaryTeal,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            doc.specialization,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Reg: ${doc.registrationNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // Details grid
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hospital: ${doc.hospitalName ?? "Independent Clinic"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${doc.experienceYears}y exp • ₹${doc.consultationFee.round()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Approve & Verify'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          controller.approveDoctor(doc.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.successGreen,
                              content: Text(
                                '${doc.fullName} verified successfully!',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.alertRed,
                        side: const BorderSide(color: AppTheme.alertRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        controller.rejectDoctor(
                          doc.id,
                          'Invalid medical license',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.alertRed,
                            content: Text(
                              '${doc.fullName} application rejected.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlaggedReviewsTab(
    BuildContext context,
    List<ReviewReportModel> reports,
    AdminController controller,
  ) {
    if (reports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: AppTheme.primaryTeal,
              ),
              SizedBox(height: 12),
              Text(
                'Review Moderation Clean',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'No flagged or abusive reviews reported.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rep = reports[index];
        final review = rep.review;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Reason Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: AppTheme.alertRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FLAGGED: ${rep.reason}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.alertRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Review content
                if (review != null) ...[
                  Text(
                    'Review by: ${review.patientName} (${review.rating} Stars)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      review.comment ?? 'No text comment.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete Review'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.alertRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          controller.moderateReview(
                            reportId: rep.id,
                            action: 'delete_review',
                            reviewId: rep.reviewId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Violating review deleted.'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        controller.moderateReview(
                          reportId: rep.id,
                          action: 'dismiss',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report dismissed.')),
                        );
                      },
                      child: const Text('Dismiss Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
