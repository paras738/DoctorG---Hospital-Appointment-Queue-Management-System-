import 'package:flutter/foundation.dart';

import '../../doctor_directory/domain/models/doctor_review_model.dart';

@immutable
class ReviewReportModel {
  final String id;
  final String reviewId;
  final String reporterId;
  final String reason;
  final String status; // 'pending', 'resolved', 'dismissed'
  final DateTime createdAt;
  final DoctorReviewModel? review;

  const ReviewReportModel({
    required this.id,
    required this.reviewId,
    required this.reporterId,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
    this.review,
  });

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isDismissed => status == 'dismissed';

  factory ReviewReportModel.fromJson(Map<String, dynamic> json) {
    DoctorReviewModel? parsedReview;
    if (json['reviews'] != null && json['reviews'] is Map) {
      parsedReview = DoctorReviewModel.fromJson(
        json['reviews'] as Map<String, dynamic>,
      );
    }

    return ReviewReportModel(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      reporterId: json['reporter_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      review: parsedReview,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'reporter_id': reporterId,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
