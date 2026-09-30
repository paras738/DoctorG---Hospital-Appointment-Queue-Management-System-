import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/cache/cache_service.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../domain/models/doctor_model.dart';
import '../../domain/models/doctor_filter.dart';
import '../../domain/models/doctor_review_model.dart';
import '../../domain/repositories/doctor_repository.dart';

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  return SupabaseDoctorRepository(supabase, cache);
});

class SupabaseDoctorRepository implements DoctorRepository {
  final SupabaseClient _supabase;
  final CacheService _cache;

  SupabaseDoctorRepository(this._supabase, this._cache);

  @override
  Future<List<DoctorModel>> getDoctors({
    required String city,
    String? searchQuery,
    required DoctorFilter filter,
    int page = 0,
    int pageSize = 20,
    double? userLat,
    double? userLng,
  }) async {
    try {
      // 1. Resolve symptom query if search string is present
      String? matchedSpecialization;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final symptomMatch = await _supabase
            .from('symptom_mappings')
            .select('specialization')
            .ilike('symptom', '%$q%')
            .limit(1)
            .maybeSingle();

        if (symptomMatch != null) {
          matchedSpecialization = symptomMatch['specialization'] as String;
        }
      }

      // 2. Build Query on Bayesian doctor_ranking_view
      var query = _supabase.from('doctor_ranking_view').select('''
        doctor_id,
        full_name,
        registration_number,
        specialization,
        experience_years,
        consultation_fee,
        languages,
        photo_url,
        bio,
        is_verified,
        is_available_today,
        is_available_now,
        avg_consultation_minutes,
        review_count,
        avg_rating,
        bayesian_score,
        is_top_rated,
        doctor_hospitals (
          hospital:hospitals (
            name,
            address,
            city,
            location
          )
        )
      ''');

      // 3. Filter by Specialization or Matched Symptom
      if (filter.specialization != null && filter.specialization!.isNotEmpty) {
        query = query.eq('specialization', filter.specialization!);
      } else if (matchedSpecialization != null) {
        query = query.eq('specialization', matchedSpecialization);
      } else if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim();
        query = query.or(
          'full_name.ilike.%$term%,specialization.ilike.%$term%',
        );
      }

      // 4. Filter by Fees & Availability
      if (filter.minFee > 0) {
        query = query.gte('consultation_fee', filter.minFee);
      }
      if (filter.maxFee < 2500) {
        query = query.lte('consultation_fee', filter.maxFee);
      }
      if (filter.availableToday) {
        query = query.eq('is_available_today', true);
      }
      if (filter.availableNow) {
        query = query.eq('is_available_now', true);
      }

      // 5. Database-side Ordering
      switch (filter.sortBy) {
        case DoctorSortBy.feeLowToHigh:
          query = query.order('consultation_fee', ascending: true);
          break;
        case DoctorSortBy.feeHighToLow:
          query = query.order('consultation_fee', ascending: false);
          break;
        case DoctorSortBy.experienceHigh:
          query = query.order('experience_years', ascending: false);
          break;
        case DoctorSortBy.distanceNearest:
        case DoctorSortBy.bayesianRating:
        default:
          query = query.order('bayesian_score', ascending: false);
          break;
      }

      // 6. Pagination (20 per page)
      final from = page * pageSize;
      final to = from + pageSize - 1;
      query = query.range(from, to);

      final response = await query;
      final rawList = response as List<dynamic>;

      // 7. Parse Doctors and Compute Local Straight-Line Distance
      final doctors = <DoctorModel>[];
      for (final item in rawList) {
        final map = item as Map<String, dynamic>;

        String? hospName;
        String? hospAddr;
        double? hospLat;
        double? hospLng;

        if (map['doctor_hospitals'] != null &&
            (map['doctor_hospitals'] as List).isNotEmpty) {
          final dh =
              (map['doctor_hospitals'] as List).first as Map<String, dynamic>;
          if (dh['hospital'] != null && dh['hospital'] is Map) {
            final h = dh['hospital'] as Map<String, dynamic>;
            hospName = h['name'] as String?;
            hospAddr = h['address'] as String?;
          }
        }

        double? distMeters;
        if (userLat != null &&
            userLng != null &&
            hospLat != null &&
            hospLng != null) {
          distMeters = DistanceCalculator.haversineDistanceMeters(
            userLat,
            userLng,
            hospLat,
            hospLng,
          );
        }

        final doc = DoctorModel.fromJson(map).copyWith(
          hospitalName: hospName,
          hospitalAddress: hospAddr,
          distanceMeters: distMeters,
        );

        // Distance filtering if active
        if (filter.maxDistanceKm != null && distMeters != null) {
          if (distMeters > (filter.maxDistanceKm! * 1000)) {
            continue;
          }
        }

        doctors.add(doc);
      }

      // If user requested nearest first, sort in memory based on computed distance
      if (filter.sortBy == DoctorSortBy.distanceNearest && userLat != null) {
        doctors.sort((a, b) {
          if (a.distanceMeters == null) return 1;
          if (b.distanceMeters == null) return -1;
          return a.distanceMeters!.compareTo(b.distanceMeters!);
        });
      }

      // Cache page 0 results for offline fallback
      if (page == 0 &&
          !filter.hasActiveFilters &&
          (searchQuery == null || searchQuery.isEmpty)) {
        await _cache.cacheDoctors(
          city,
          doctors.map((d) => d.toJson()).toList(),
        );
      }

      return doctors;
    } catch (e) {
      // Offline fallback: Check Hive cache
      final cached = _cache.getCachedDoctors(city);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((j) => DoctorModel.fromJson(j)).toList();
      }
      rethrow;
    }
  }

  @override
  Future<DoctorModel?> getDoctorById(
    String doctorId, {
    double? userLat,
    double? userLng,
  }) async {
    final response = await _supabase
        .from('doctor_ranking_view')
        .select('''
      doctor_id,
      full_name,
      registration_number,
      specialization,
      experience_years,
      consultation_fee,
      languages,
      photo_url,
      bio,
      is_verified,
      is_available_today,
      is_available_now,
      avg_consultation_minutes,
      review_count,
      avg_rating,
      bayesian_score,
      is_top_rated,
      doctor_hospitals (
        room_number,
        hospital:hospitals (
          name,
          address,
          city,
          phone,
          location
        )
      )
    ''')
        .eq('doctor_id', doctorId)
        .maybeSingle();

    if (response == null) return null;

    final map = response;
    String? hospName;
    String? hospAddr;
    double? hospLat;
    double? hospLng;

    if (map['doctor_hospitals'] != null &&
        (map['doctor_hospitals'] as List).isNotEmpty) {
      final dh =
          (map['doctor_hospitals'] as List).first as Map<String, dynamic>;
      if (dh['hospital'] != null && dh['hospital'] is Map) {
        final h = dh['hospital'] as Map<String, dynamic>;
        hospName = h['name'] as String?;
        hospAddr = h['address'] as String?;
      }
    }

    double? distMeters;
    if (userLat != null &&
        userLng != null &&
        hospLat != null &&
        hospLng != null) {
      distMeters = DistanceCalculator.haversineDistanceMeters(
        userLat,
        userLng,
        hospLat,
        hospLng,
      );
    }

    // Fetch next available slot
    DateTime? nextSlot;
    try {
      final slotRes = await _supabase
          .from('slots')
          .select('slot_start')
          .eq('doctor_id', doctorId)
          .eq('status', 'available')
          .gte('slot_start', DateTime.now().toIso8601String())
          .order('slot_start', ascending: true)
          .limit(1)
          .maybeSingle();

      if (slotRes != null && slotRes['slot_start'] != null) {
        nextSlot = DateTime.parse(slotRes['slot_start'] as String);
      }
    } catch (_) {}

    return DoctorModel.fromJson(map).copyWith(
      hospitalName: hospName,
      hospitalAddress: hospAddr,
      distanceMeters: distMeters,
      nextAvailableSlot: nextSlot,
    );
  }

  @override
  Future<List<DoctorReviewModel>> getDoctorReviews(
    String doctorId, {
    int limit = 20,
  }) async {
    final response = await _supabase
        .from('reviews')
        .select('''
          id,
          appointment_id,
          doctor_id,
          patient_id,
          rating,
          comment,
          doctor_reply,
          doctor_replied_at,
          created_at,
          profiles:patient_id (
            full_name
          )
        ''')
        .eq('doctor_id', doctorId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = response as List<dynamic>;
    return list
        .map((item) => DoctorReviewModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<String>> getSpecializations() async {
    try {
      final response = await _supabase
          .from('doctors')
          .select('specialization')
          .eq('is_verified', true);

      final rawList = response as List<dynamic>;
      final set = <String>{};
      for (final item in rawList) {
        final s = item['specialization'] as String?;
        if (s != null && s.isNotEmpty) set.add(s);
      }
      final result = set.toList()..sort();
      return result.isNotEmpty
          ? result
          : [
              'Cardiologist',
              'Dermatologist',
              'General Physician',
              'Pediatrician',
              'Orthopedic',
              'Gynecologist',
              'ENT Specialist',
              'Neurologist',
              'Dentist',
              'Psychiatrist',
            ];
    } catch (_) {
      return [
        'Cardiologist',
        'Dermatologist',
        'General Physician',
        'Pediatrician',
        'Orthopedic',
        'Gynecologist',
        'ENT Specialist',
        'Neurologist',
        'Dentist',
        'Psychiatrist',
      ];
    }
  }

  @override
  Future<List<Map<String, String>>> getPopularSymptoms() async {
    return [
      {
        'symptom': 'Chest Pain',
        'specialization': 'Cardiologist',
        'icon': 'favorite',
      },
      {
        'symptom': 'Skin Rash',
        'specialization': 'Dermatologist',
        'icon': 'healing',
      },
      {
        'symptom': 'Fever & Cough',
        'specialization': 'General Physician',
        'icon': 'thermostat',
      },
      {
        'symptom': 'Child Care',
        'specialization': 'Pediatrician',
        'icon': 'child_care',
      },
      {
        'symptom': 'Joint Pain',
        'specialization': 'Orthopedic',
        'icon': 'accessibility',
      },
      {
        'symptom': 'Toothache',
        'specialization': 'Dentist',
        'icon': 'sentiment_satisfied',
      },
      {
        'symptom': 'Ear / Throat',
        'specialization': 'ENT Specialist',
        'icon': 'hearing',
      },
      {
        'symptom': 'Migraine',
        'specialization': 'Neurologist',
        'icon': 'psychology',
      },
    ];
  }
}
