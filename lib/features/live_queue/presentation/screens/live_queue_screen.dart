import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../doctor_directory/presentation/controllers/doctor_directory_controller.dart';
import '../controllers/live_queue_controller.dart';
import '../../domain/models/queue_state_model.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';

class LiveQueueScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final int userToken;

  const LiveQueueScreen({
    super.key,
    required this.doctorId,
    this.userToken = 12, // Default sample token if accessed directly
  });

  @override
  ConsumerState<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends ConsumerState<LiveQueueScreen>
    with WidgetsBindingObserver {
  bool _audioAlertsEnabled = true;
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Free-tier constraint: notice when app is paused/hidden to avoid unnecessary streaming
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (mounted) setState(() => _isBackgrounded = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isBackgrounded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = LiveQueueParams(
      doctorId: widget.doctorId,
      date: DateTime.now(),
      userToken: widget.userToken,
    );

    // Watch auto-disposing single-channel stream
    final queueAsync = ref.watch(liveQueueStreamProvider(params));
    final doctorAsync = ref.watch(doctorProfileProvider(widget.doctorId));

    final doctor = doctorAsync.valueOrNull;
    final doctorName = doctor != null ? 'Dr. ${doctor.name}' : 'Doctor OPD';
    final hospitalName = doctor?.hospitalName ?? 'City Hospital, Bengaluru';
    final specialization = doctor?.specialization ?? 'General Physician';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              specialization,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBadgeButton(iconColor: Colors.white),
          IconButton(
            icon: Icon(
              _audioAlertsEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            tooltip: _audioAlertsEnabled
                ? 'Mute Sound Alerts'
                : 'Enable Sound Alerts',
            onPressed: () {
              setState(() => _audioAlertsEnabled = !_audioAlertsEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    _audioAlertsEnabled
                        ? 'Sound alerts active when your turn arrives'
                        : 'Sound alerts muted',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Queue',
            onPressed: () {
              ref.invalidate(liveQueueStreamProvider(params));
            },
          ),
        ],
      ),
      body: queueAsync.when(
        data: (qState) {
          if (qState == null) {
            return const Center(child: Text('No active queue for today.'));
          }
          return _buildQueueContent(
            qState,
            doctorName,
            hospitalName,
            specialization,
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text('Realtime stream reconnecting: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(liveQueueStreamProvider(params)),
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueContent(
    QueueStateModel qState,
    String doctorName,
    String hospitalName,
    String specialization,
  ) {
    final ahead = qState.patientsAhead(widget.userToken);
    final waitMinutes = qState.estimatedWaitMinutes(widget.userToken);
    final alertLevel = qState.getAlertLevel(widget.userToken);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Connection status bar
          _buildStatusBar(qState),
          const SizedBox(height: 12),

          // 2. Doctor OPD Delay or Pause Announcement (if any)
          if (qState.isPaused)
            _buildPauseBanner()
          else if (qState.delayMinutes > 0)
            _buildDelayBanner(qState.delayMinutes),

          // 3. Smart Alert Card (Dynamic based on queue position)
          _buildSmartAlertBanner(alertLevel, ahead, waitMinutes),
          const SizedBox(height: 16),

          // 4. Large Live Queue Token Display
          _buildLiveTokenCard(qState, ahead, waitMinutes),
          const SizedBox(height: 16),

          // 5. Visual Progress Tracker
          _buildProgressTracker(qState),
          const SizedBox(height: 16),

          // 6. Clinic & OPD Location Info Card
          _buildClinicInfoCard(doctorName, hospitalName, specialization),
          const SizedBox(height: 16),

          // 7. Navigation & Quick Actions
          _buildActionButtons(hospitalName),
        ],
      ),
    );
  }

  Widget _buildStatusBar(QueueStateModel qState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: qState.isActive
            ? AppTheme.primaryLightTeal
            : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: qState.isActive ? AppTheme.primaryTeal : Colors.amber,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: qState.isActive ? AppTheme.successGreen : Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isBackgrounded
                ? 'STANDBY (BACKGROUND)'
                : qState.isActive
                ? 'LIVE REALTIME QUEUE CONNECTED'
                : 'QUEUE PAUSED BY CLINIC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isBackgrounded
                  ? Colors.blueGrey
                  : qState.isActive
                  ? AppTheme.primaryDarkTeal
                  : Colors.amber.shade900,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            'Updated ${_formatTime(qState.updatedAt)}',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_filled, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Doctor has paused consultations temporarily. Queue will resume shortly.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelayBanner(int delayMinutes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time_filled,
            color: Colors.deepOrange,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Doctor is running $delayMinutes min delayed due to an emergency OPD case.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartAlertBanner(
    QueueAlertLevel level,
    int ahead,
    int waitMinutes,
  ) {
    Color bg;
    Color border;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    switch (level) {
      case QueueAlertLevel.serving:
        bg = Colors.green.shade50;
        border = AppTheme.successGreen;
        textColor = Colors.green.shade900;
        icon = Icons.door_front_door_rounded;
        title = "IT'S YOUR TURN NOW!";
        subtitle = "Please enter Doctor's Cabin (Room 204).";
        break;
      case QueueAlertLevel.nextInLine:
        bg = Colors.indigo.shade50;
        border = Colors.indigo;
        textColor = Colors.indigo.shade900;
        icon = Icons.notifications_active_rounded;
        title = "YOU ARE NEXT IN LINE (#${widget.userToken})";
        subtitle =
            "Please stand outside the consultation room. Turn in ~${waitMinutes}m.";
        break;
      case QueueAlertLevel.leaveNow:
        bg = const Color(0xFFFFF3E0);
        border = Colors.orange;
        textColor = Colors.orange.shade900;
        icon = Icons.directions_car_rounded;
        title = "TIME TO LEAVE FOR CLINIC NOW!";
        subtitle =
            "Only $ahead patients ahead of you. Estimated wait: ~$waitMinutes min.";
        break;
      case QueueAlertLevel.completed:
        bg = Colors.grey.shade100;
        border = Colors.grey;
        textColor = Colors.grey.shade800;
        icon = Icons.check_circle_outline_rounded;
        title = "CONSULTATION COMPLETED";
        subtitle = "Thank you for using DoctorG. Hope you recover quickly!";
        break;
      case QueueAlertLevel.skipped:
        bg = Colors.red.shade50;
        border = AppTheme.alertRed;
        textColor = Colors.red.shade900;
        icon = Icons.warning_amber_rounded;
        title = "TOKEN MISSED / NO-SHOW";
        subtitle = "Contact receptionist for 5-minute grace re-entry.";
        break;
      case QueueAlertLevel.waiting:
        bg = const Color(0xFFE0F2F1);
        border = AppTheme.primaryTeal;
        textColor = AppTheme.primaryDarkTeal;
        icon = Icons.schedule_rounded;
        title = "RELAX, YOU HAVE TIME";
        subtitle =
            "$ahead patients ahead of you. We'll notify you when 3 patients remain.";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: border.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTokenCard(
    QueueStateModel qState,
    int ahead,
    int waitMinutes,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top token comparison
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Now Serving
                Column(
                  children: [
                    const Text(
                      'NOW SERVING',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryTeal,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '#${qState.currentToken}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkTeal,
                        ),
                      ),
                    ),
                  ],
                ),

                // Arrow Divider
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.grey,
                  size: 28,
                ),

                // Your Token
                Column(
                  children: [
                    const Text(
                      'YOUR TOKEN',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.accentAmber,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '#${widget.userToken}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 36),

            // Metrics row: Patients Ahead & Est Wait
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$ahead',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Patients Ahead',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: Colors.grey.shade300),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '~$waitMinutes min',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Estimated Wait',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTracker(QueueStateModel qState) {
    final total = qState.lastToken > 0 ? qState.lastToken : 20;
    final current = qState.currentToken.clamp(0, total);

    final currentFraction = total > 0 ? current / total : 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'OPD Queue Progress',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Token $current of $total',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: currentFraction,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryTeal,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Token visual stepping preview
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                (qState.lastToken > 0 ? qState.lastToken : 15).clamp(1, 16),
                (idx) {
                  final tokenNum = idx + 1;
                  final isCurrent = tokenNum == qState.currentToken;
                  final isUser = tokenNum == widget.userToken;
                  final isDone = tokenNum < qState.currentToken;

                  Color bg = Colors.grey.shade100;
                  Color text = Colors.grey.shade700;
                  Border? border;

                  if (isDone) {
                    bg = Colors.grey.shade300;
                    text = Colors.grey.shade500;
                  }
                  if (isCurrent) {
                    bg = AppTheme.primaryTeal;
                    text = Colors.white;
                  }
                  if (isUser) {
                    border = Border.all(color: AppTheme.accentAmber, width: 2);
                  }

                  return Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Text(
                      '$tokenNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (isCurrent || isUser)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: text,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicInfoCard(
    String doctorName,
    String hospitalName,
    String specialization,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinic & Consultation Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.local_hospital_outlined,
                  size: 20,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hospitalName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 20,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 10),
                const Text(
                  'OPD Room 204 (2nd Floor, Wing B)',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Helpdesk: +91 80 2345 6789',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String hospitalName) {
    return Column(
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.directions_rounded),
          label: const Text('View Hospital on Map & Route'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppTheme.primaryTeal,
          ),
          onPressed: () {
            context.go('/home');
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Contact Reception Desk'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Calling Hospital Reception: +91 80 2345 6789...',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }
}
