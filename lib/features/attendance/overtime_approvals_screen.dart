import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

/// Pending requests are scoped by the backend to the manager's team/company.
class OvertimeApprovalsScreen extends StatefulWidget {
  const OvertimeApprovalsScreen({super.key});

  @override
  State<OvertimeApprovalsScreen> createState() =>
      _OvertimeApprovalsScreenState();
}

class _OvertimeApprovalsScreenState extends State<OvertimeApprovalsScreen> {
  final _scroll = ScrollController();
  final List<OvertimeEntry> _requests = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _deciding;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 260 &&
        !_loading &&
        !_loadingMore &&
        _hasMore)
      _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _requests.clear();
      });
    } else {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }
    try {
      final items = await AppScope.read(context).repository
          .fetchOvertimeRequests(status: 'PENDING', page: _page, limit: 20);
      if (!mounted) return;
      setState(() {
        _requests.addAll(items);
        _hasMore = items.length == 20;
        _page++;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.statusCode == 403
              ? 'You do not have permission to review overtime requests for this team or company.'
              : error.message;
          _loading = false;
          _loadingMore = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  Future<void> _decide(OvertimeEntry request, String decision) async {
    final approved = decision == 'APPROVED';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'Approve overtime?' : 'Reject overtime?'),
        content: Text(
          '${request.employeeName.isEmpty ? request.employeeId : request.employeeName} · ${Formatters.dayMonthYear(request.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approved ? 'APPROVE' : 'REJECT'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _deciding = request.id);
    try {
      await AppScope.read(
        context,
      ).repository.decideOvertime(id: request.id, decision: decision);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Overtime approved.' : 'Overtime rejected.'),
        ),
      );
      await _load(reset: true);
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.statusCode == 403
                  ? 'You are not authorized to decide this request.'
                  : error.message,
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _deciding = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Overtime Approvals'),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _requests.isEmpty
        ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
        : RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: _requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 140),
                      EmptyState(
                        icon: Icons.more_time_rounded,
                        title: 'No pending requests',
                        message: 'New overtime requests will appear here.',
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      14,
                      AppTheme.gutter,
                      24,
                    ),
                    itemCount: _requests.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _requests.length)
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      final request = _requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestCard(
                          request: request,
                          busy: _deciding == request.id,
                          onDecision: (value) => _decide(request, value),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onDecision,
  });
  final OvertimeEntry request;
  final bool busy;
  final ValueChanged<String> onDecision;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.employeeName.isEmpty
              ? (request.employeeId.isEmpty ? 'Employee' : request.employeeId)
              : request.employeeName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        if (request.employeeId.isNotEmpty && request.employeeName.isNotEmpty)
          Text(
            'ID: ${request.employeeId}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        const SizedBox(height: 8),
        Text(
          '${Formatters.dayMonthYear(request.date)}${request.hours > 0 ? ' · ${Formatters.hoursMinutes(request.hours)}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (request.startTime != null)
          Text(
            'Started ${TimeOfDay.fromDateTime(request.startTime!.toLocal()).format(context)}${request.endTime == null ? '' : ' · ended ${TimeOfDay.fromDateTime(request.endTime!.toLocal()).format(context)}'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        if (request.reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(request.reason),
          ),
        if (request.breakMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Break: ${request.breakMinutes} minutes',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LinearProgressIndicator(),
          )
        else if (request.employeeId.isNotEmpty &&
            request.employeeId == AppScope.of(context).data.employee?.id)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'You cannot approve your own request.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onDecision('REJECTED'),
                    child: const Text('REJECT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onDecision('APPROVED'),
                    child: const Text('APPROVE'),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
