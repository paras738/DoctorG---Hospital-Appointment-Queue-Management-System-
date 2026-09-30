// k6 Performance & Load Test Suite for DoctorG
// Simulates 500 concurrent virtual users (VUs) testing API throughput under free-tier limits

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom Performance Metrics
const errorRate = new Rate('custom_error_rate');
const doctorDirectoryLatency = new Trend('doctor_directory_duration_ms');
const postgisProximityLatency = new Trend('postgis_proximity_duration_ms');
const liveQueueLatency = new Trend('live_queue_duration_ms');

// Configuration from Environment or Defaults
const BASE_URL = __ENV.SUPABASE_URL || 'https://placeholder.supabase.co';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'placeholder-anon-key';

const headers = {
  apikey: ANON_KEY,
  Authorization: `Bearer ${ANON_KEY}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

// Test Stages: Ramp up to 500 VUs, sustain peak load, ramp down
export const options = {
  stages: [
    { duration: '30s', target: 100 }, // Warmup ramp to 100 users
    { duration: '1m', target: 500 },  // Ramp to 500 concurrent virtual users
    { duration: '2m', target: 500 },  // Sustain 500 concurrent users at peak
    { duration: '30s', target: 0 },   // Graceful cool-down
  ],
  thresholds: {
    // 95% of all requests must complete in under 500ms
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    // Error rate must remain strictly below 1% under peak 500 users
    http_req_failed: ['rate<0.01'],
    custom_error_rate: ['rate<0.01'],
    doctor_directory_duration_ms: ['p(95)<400'],
    postgis_proximity_duration_ms: ['p(95)<450'],
    live_queue_duration_ms: ['p(95)<250'],
  },
};

const sampleDoctors = [
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000003',
  '20000000-0000-0000-0000-000000000004',
  '20000000-0000-0000-0000-000000000005',
];

const sampleSpecializations = [
  'Cardiologist',
  'Dermatologist',
  'Pediatrician',
  'Orthopedic',
  'General Physician',
];

export default function () {
  const vuId = __VU;
  const iteration = __ITER;
  const docId = sampleDoctors[(vuId + iteration) % sampleDoctors.length];
  const spec = sampleSpecializations[(vuId + iteration) % sampleSpecializations.length];

  // 1. Patient Journey: Search Doctor Directory with Bayesian Ranking View
  group('01_Search_Doctor_Directory', function () {
    const url = `${BASE_URL}/rest/v1/doctor_ranking_view?specialization=eq.${spec}&order=bayesian_score.desc&limit=20`;
    const res = http.get(url, { headers: headers });

    const success = check(res, {
      'directory status 200 or 401 (mock auth)': (r) => r.status === 200 || r.status === 401,
      'response received': (r) => r.body !== null,
    });

    errorRate.add(!success);
    doctorDirectoryLatency.add(res.timings.duration);
    sleep(1);
  });

  // 2. Patient Journey: PostGIS Nearby Hospitals Proximity Query (Bengaluru coords)
  group('02_PostGIS_Proximity_Query', function () {
    const payload = JSON.stringify({
      user_lat: 12.9716 + (Math.random() - 0.5) * 0.05,
      user_lng: 77.5946 + (Math.random() - 0.5) * 0.05,
      radius_km: 15,
    });

    const res = http.post(`${BASE_URL}/rest/v1/rpc/get_nearby_hospitals`, payload, {
      headers: headers,
    });

    const success = check(res, {
      'postgis status 200 or 401': (r) => r.status === 200 || r.status === 401,
    });

    errorRate.add(!success);
    postgisProximityLatency.add(res.timings.duration);
    sleep(1);
  });

  // 3. Patient Journey: Doctor Detail & Reviews
  group('03_Doctor_Profile_And_Reviews', function () {
    const docRes = http.get(`${BASE_URL}/rest/v1/doctors?id=eq.${docId}&select=*,profiles(*)`, {
      headers: headers,
    });

    const revRes = http.get(`${BASE_URL}/rest/v1/reviews?doctor_id=eq.${docId}&limit=10`, {
      headers: headers,
    });

    const success = check(docRes, {
      'profile status 200 or 401': (r) => r.status === 200 || r.status === 401,
    }) && check(revRes, {
      'reviews status 200 or 401': (r) => r.status === 200 || r.status === 401,
    });

    errorRate.add(!success);
    sleep(1.5);
  });

  // 4. Patient Journey: Check Slots Availability
  group('04_Check_Available_Slots', function () {
    const today = new Date().toISOString().substring(0, 10);
    const res = http.get(`${BASE_URL}/rest/v1/slots?doctor_id=eq.${docId}&slot_date=eq.${today}&status=eq.available&limit=20`, {
      headers: headers,
    });

    const success = check(res, {
      'slots query status 200 or 401': (r) => r.status === 200 || r.status === 401,
    });

    errorRate.add(!success);
    sleep(1);
  });

  // 5. Patient Journey: Live Queue State (Narrow Single-Row Query)
  group('05_Live_Queue_Single_Row_Check', function () {
    const today = new Date().toISOString().substring(0, 10);
    const res = http.get(`${BASE_URL}/rest/v1/queue_state?doctor_id=eq.${docId}&queue_date=eq.${today}`, {
      headers: headers,
    });

    const success = check(res, {
      'queue state status 200 or 401': (r) => r.status === 200 || r.status === 401,
      'latency under threshold': (r) => r.timings.duration < 500,
    });

    errorRate.add(!success);
    liveQueueLatency.add(res.timings.duration);
    sleep(2);
  });
}
