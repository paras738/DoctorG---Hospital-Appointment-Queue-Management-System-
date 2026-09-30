import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../live_queue/domain/models/queue_state_model.dart';
import '../../../live_queue/domain/models/queue_token_model.dart';
import '../../../live_queue/presentation/controllers/live_queue_controller.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  final String? doctorId;

  const DoctorDashboardScreen({super.key, this.doctorId});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final resolvedDoctorId =
        widget.doctorId ?? user?.id ?? '20000000-0000-0000-0000-00000001';

    final queueState = ref.watch(
      doctorQueueControllerProvider(resolvedDoctorId),
    );
    final controller = ref.read(
      doctorQueueControllerProvider(resolvedDoctorId).notifier,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName
                  : 'Doctor OPD Dashboard',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Live Clinic Queue & Patient Controls',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Queue',
            onPressed: () => controller.loadQueue(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: queueState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            )
          : RefreshIndicator(
              onRefresh: () => controller.loadQueue(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Doctor Availability & Live OPD Toggle
                    _buildAvailabilityToggleCard(queueState, controller),
                    const SizedBox(height: 14),

                    // 2. Metrics Bar (Waiting, Active, Completed, Skipped)
                    _buildMetricsGrid(queueState),
                    const SizedBox(height: 14),

                    // 3. Active OPD Console (Now Serving & Next Patient)
                    _buildActiveConsole(queueState, controller),
                    const SizedBox(height: 14),

                    // 4. OPD Delay Announcement Bar
                    _buildDelayControl(queueState, controller),
                    const SizedBox(height: 14),

                    // 5. Patient Queue Tabs (Waiting, All, Done)
                    _buildQueueTabsSection(queueState, controller),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvailabilityToggleCard(
    DoctorQueueState state,
    DoctorQueueController controller,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: state.isAvailableNow
                    ? AppTheme.successGreen
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.isAvailableNow
                        ? 'Available Now — Live Queue Active'
                        : 'Doctor Offline / Clinic Closed',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    state.isAvailableNow
                        ? 'Boosts your profile ranking for nearby patient searches'
                        : 'Patients cannot enter new walk-in queue tokens',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Switch(
              value: state.isAvailableNow,
              activeColor: AppTheme.primaryTeal,
              onChanged: (val) => controller.toggleAvailability(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(DoctorQueueState state) {
    final currentToken = state.queueState?.currentToken ?? 0;
    final totalTokens = state.tokens.length;

    return Row(
      children: [
        _buildMetricTile(
          'Serving',
          '#$currentToken',
          AppTheme.primaryTeal,
          Icons.play_circle_fill_rounded,
        ),
        const SizedBox(width: 8),
        _buildMetricTile(
          'Waiting',
          '${state.waitingCount}',
          Colors.orange,
          Icons.people_alt_rounded,
        ),
        const SizedBox(width: 8),
        _buildMetricTile(
          'Completed',
          '${state.completedCount}',
          AppTheme.successGreen,
          Icons.check_circle_rounded,
        ),
        const SizedBox(width: 8),
        _buildMetricTile(
          'Total Today',
          '$totalTokens',
          Colors.blueGrey,
          Icons.confirmation_number_rounded,
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveConsole(
    DoctorQueueState state,
    DoctorQueueController controller,
  ) {
    final servingToken = state.currentServingToken;
    final isPaused = state.queueState?.isPaused ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NOW SERVING IN CABIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.grey,
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    size: 16,
                  ),
                  label: Text(
                    isPaused ? 'Resume Queue' : 'Pause Queue',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => controller.toggleQueuePause(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (servingToken != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryTeal, width: 2),
                    ),
                    child: Text(
                      '#${servingToken.tokenNumber}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDarkTeal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          servingToken.patientName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${servingToken.patientGender} • ${servingToken.patientAge} yrs • ${servingToken.patientPhone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (servingToken.consultationReason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${servingToken.consultationReason}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons: Complete / No-Show
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Mark Complete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                      ),
                      onPressed: () => controller.markComplete(servingToken.id),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_off_outlined, size: 18),
                    label: const Text('No-Show'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: const BorderSide(color: AppTheme.alertRed),
                    ),
                    onPressed: () =>
                        _confirmNoShowDialog(context, servingToken, controller),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chair_outlined, color: Colors.grey, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cabin is currently empty. Ready to call the next waiting patient.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 28),

            // Call Next Patient Button
            FilledButton.icon(
              icon: const Icon(Icons.record_voice_over_rounded),
              label: const Text(
                'CALL NEXT PATIENT',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppTheme.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => controller.callNextPatient(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayControl(
    DoctorQueueState state,
    DoctorQueueController controller,
  ) {
    final currentDelay = state.queueState?.delayMinutes ?? 0;

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
                  'OPD Delay Announcement',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (currentDelay > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Running +$currentDelay min delayed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _buildDelayChip(controller, currentDelay, 0, 'On Time (0m)'),
                _buildDelayChip(controller, currentDelay, 10, '+10 mins'),
                _buildDelayChip(controller, currentDelay, 20, '+20 mins'),
                _buildDelayChip(controller, currentDelay, 30, '+30 mins'),
                _buildDelayChip(controller, currentDelay, 45, '+45 mins'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayChip(
    DoctorQueueController controller,
    int currentDelay,
    int minutes,
    String label,
  ) {
    final isSelected = currentDelay == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: minutes == 0
          ? AppTheme.primaryLightTeal
          : Colors.orange.shade200,
      onSelected: (_) => controller.announceDelay(minutes),
    );
  }

  Widget _buildQueueTabsSection(
    DoctorQueueState state,
    DoctorQueueController controller,
  ) {
    final waitingTokens = state.tokens
        .where(
          (t) =>
              t.status == TokenProgressStatus.waiting ||
              t.status == TokenProgressStatus.called,
        )
        .toList();

    final completedTokens = state.tokens
        .where(
          (t) =>
              t.status == TokenProgressStatus.completed ||
              t.status == TokenProgressStatus.skipped,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryTeal,
          tabs: [
            Tab(text: 'Waiting (${waitingTokens.length})'),
            Tab(text: 'All (${state.tokens.length})'),
            Tab(text: 'History (${completedTokens.length})'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTokenListView(
                waitingTokens,
                controller,
                isWaitingTab: true,
              ),
              _buildTokenListView(state.tokens, controller),
              _buildTokenListView(completedTokens, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenListView(
    List<QueueTokenModel> tokens,
    DoctorQueueController controller, {
    bool isWaitingTab = false,
  }) {
    if (tokens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isWaitingTab ? Icons.done_all_rounded : Icons.inbox_outlined,
                size: 40,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                isWaitingTab
                    ? 'All waiting patients have been attended!'
                    : 'No patients in this queue yet.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final token = tokens[index];
        return _buildTokenRow(token, controller);
      },
    );
  }

  Widget _buildTokenRow(
    QueueTokenModel token,
    DoctorQueueController controller,
  ) {
    Color tagColor;
    String tagLabel;

    switch (token.status) {
      case TokenProgressStatus.called:
        tagColor = Colors.orange;
        tagLabel = 'CALLED';
        break;
      case TokenProgressStatus.withDoctor:
        tagColor = AppTheme.primaryTeal;
        tagLabel = 'IN CABIN';
        break;
      case TokenProgressStatus.completed:
        tagColor = AppTheme.successGreen;
        tagLabel = 'COMPLETED';
        break;
      case TokenProgressStatus.skipped:
        tagColor = AppTheme.alertRed;
        tagLabel = 'NO-SHOW';
        break;
      case TokenProgressStatus.waiting:
      default:
        tagColor = Colors.grey;
        tagLabel = 'WAITING';
        break;
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${token.tokenNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: tagColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.patientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${token.patientGender} • ${token.patientAge} yrs • ${token.patientPhone}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tagLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: tagColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmNoShowDialog(
    BuildContext context,
    QueueTokenModel token,
    DoctorQueueController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Patient as No-Show?'),
        content: Text(
          'Patient ${token.patientName} (Token #${token.tokenNumber}) will be marked as no-show. A 5-minute grace period will be initiated for reception desk re-entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () {
              Navigator.pop(ctx);
              controller.markNoShowWithGrace(token.id);
            },
            child: const Text('Confirm No-Show'),
          ),
        ],
      ),
    );
  }
}
