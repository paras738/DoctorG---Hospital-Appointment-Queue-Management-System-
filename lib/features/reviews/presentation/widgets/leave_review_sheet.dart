import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/supabase_reviews_repository.dart';

class LeaveReviewSheet extends ConsumerStatefulWidget {
  final String appointmentId;
  final String doctorId;
  final String doctorName;

  const LeaveReviewSheet({
    super.key,
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  ConsumerState<LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends ConsumerState<LeaveReviewSheet> {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  final List<String> _quickTags = [
    'Polite Doctor',
    'Accurate Diagnosis',
    'Short Wait Time',
    'Detailed Explanation',
    'Clean Clinic',
    'Supportive Staff',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      final patientId = user?.id ?? '30000000-0000-0000-0000-000000000001';

      String combinedComment = _commentController.text.trim();
      if (_selectedTags.isNotEmpty) {
        final tagsStr = _selectedTags.join(', ');
        combinedComment = combinedComment.isEmpty
            ? tagsStr
            : '$combinedComment\n\nHighlights: $tagsStr';
      }

      final repo = ref.read(reviewsRepositoryProvider);
      await repo.submitVerifiedReview(
        appointmentId: widget.appointmentId,
        doctorId: widget.doctorId,
        patientId: patientId,
        rating: _selectedRating,
        comment: combinedComment.isNotEmpty ? combinedComment : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text('Verified review submitted successfully. Thank you!'),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.alertRed,
            content: Text('Could not submit review: $err'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Verified Patient Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightTeal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: AppTheme.primaryDarkTeal,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED APPOINTMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              'Review ${widget.doctorName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your honest feedback directly informs DoctorG Bayesian ratings and helps other patients.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),

            // Star Rating Selector
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    iconSize: 38,
                    icon: Icon(
                      starNum <= _selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      color: AppTheme.accentAmber,
                    ),
                    onPressed: () => setState(() => _selectedRating = starNum),
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                _getRatingLabel(_selectedRating),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentAmber,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Highlight Chips
            const Text(
              'What stood out during your visit?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryLightTeal,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Comment text area
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your consultation experience (optional)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            FilledButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppTheme.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit Verified Review',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int r) {
    switch (r) {
      case 5:
        return '5 Stars — Excellent Consultation';
      case 4:
        return '4 Stars — Very Good Experience';
      case 3:
        return '3 Stars — Average Service';
      case 2:
        return '2 Stars — Dissatisfied';
      case 1:
      default:
        return '1 Star — Poor Consultation';
    }
  }
}
