import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import 'service_report_create_screen.dart';

/// Active-work screen: site photos and field-work completion.
///
/// This is where a job goes from IN PROGRESS to COMPLETED. Photos and a
/// detailed service report is submitted once the work order is completed.
class WorkExecutionScreen extends StatefulWidget {
  const WorkExecutionScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<WorkExecutionScreen> createState() => _WorkExecutionScreenState();
}

class _WorkExecutionScreenState extends State<WorkExecutionScreen> {
  final _imagePicker = ImagePicker();
  final List<PendingPhoto> _pendingPhotos = [];
  bool _uploadingPhotos = false;
  int _uploadingPhotoIndex = 0;
  int _photoUploadTotal = 0;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        picked = image == null ? const <XFile>[] : <XFile>[image];
      } else {
        picked = await _imagePicker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
      }
      if (picked.isEmpty || !mounted) return;
      final photos = <PendingPhoto>[];
      for (final file in picked) {
        final contentType = _photoContentType(file);
        if (contentType == null) {
          _snack(context, 'Use JPEG, PNG, or WEBP photos only.');
          continue;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        photos.add(
          PendingPhoto(file: file, bytes: bytes, contentType: contentType),
        );
      }
      if (mounted) setState(() => _pendingPhotos.addAll(photos));
    } catch (_) {
      if (mounted) _snack(context, 'Could not access the camera or gallery.');
    }
  }

  Future<void> _uploadPhotos() async {
    if (_pendingPhotos.isEmpty || _uploadingPhotos) return;
    setState(() {
      _uploadingPhotos = true;
      _uploadingPhotoIndex = 0;
      _photoUploadTotal = _pendingPhotos.length;
    });
    final controller = AppScope.read(context);
    final job = AppScope.of(
      context,
    ).data.jobs.where((item) => item.id == widget.jobId).firstOrNull;
    while (_pendingPhotos.isNotEmpty && mounted) {
      final batch = _pendingPhotos.take(10).toList();
      final result = await controller.uploadWorkReportPhotos(
        workOrderId: widget.jobId,
        serviceReportId: job?.report?.id,
        files: batch
            .map(
              (photo) => WorkPhotoUploadFile(
                fileName: photo.file.name,
                bytes: photo.bytes,
                contentType: photo.contentType,
              ),
            )
            .toList(),
      );
      if (!mounted) return;
      if (result case Failure<WorkPhotoUploadResult>(:final message)) {
        setState(() => _uploadingPhotos = false);
        _snack(context, message);
        return;
      }
      final response = (result as Success<WorkPhotoUploadResult>).value;
      if (response.failures.isEmpty) {
        setState(() {
          _pendingPhotos.removeRange(0, batch.length);
          _uploadingPhotoIndex += batch.length;
        });
        continue;
      }
      final failedNames = response.failures
          .map((failure) => failure.fileName.trim().split('/').last)
          .where((name) => name.isNotEmpty)
          .toSet();
      final canMapFailures =
          failedNames.isNotEmpty &&
          response.photos.length + failedNames.length == batch.length &&
          failedNames.every(
            (name) => batch.any((photo) => photo.file.name == name),
          );
      if (canMapFailures) {
        setState(() {
          _pendingPhotos.removeWhere(
            (photo) => !failedNames.contains(photo.file.name),
          );
          _uploadingPhotoIndex += batch.length - failedNames.length;
        });
      }
      _snack(
        context,
        response.failures
            .map(
              (failure) => failure.fileName.isEmpty
                  ? failure.message
                  : '${failure.fileName}: ${failure.message}',
            )
            .join('\n'),
      );
      setState(() => _uploadingPhotos = false);
      return;
    }

    if (mounted) {
      setState(() => _uploadingPhotos = false);
      _snack(context, 'Photos uploaded.');
    }
  }

  String? _photoContentType(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      return mime;
    }
    return switch (file.name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  void _removePhoto(int index) {
    if (_uploadingPhotos) return;
    setState(() => _pendingPhotos.removeAt(index));
  }

  Future<void> _complete() async {
    if (_uploadingPhotos) return;
    if (_pendingPhotos.isNotEmpty) {
      await _uploadPhotos();
      if (!mounted || _pendingPhotos.isNotEmpty) return;
    }
    final result = await AppScope.read(context).completeJob(widget.jobId);
    if (!mounted) return;

    if (result is Failure<WorkJob>) {
      _snack(context, result.error!);
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _CompletedScreen(jobId: widget.jobId),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final matches = data.jobs.where((j) => j.id == widget.jobId);

    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Work')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.gutter),
            child: Text(
              'This work order is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final job = matches.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Active Work'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                20,
              ),
              children: [
                JobStrip(job: job),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Site Photos'),
                PhotoPanel(
                  job: job,
                  pendingPhotos: _pendingPhotos,
                  uploading: _uploadingPhotos,
                  uploadProgress: _pendingPhotos.isEmpty
                      ? 0
                      : _uploadingPhotoIndex / _photoUploadTotal,
                  uploadIndex: _uploadingPhotoIndex,
                  uploadTotal: _photoUploadTotal,
                  onAdd: _addPhoto,
                  onRemove: _removePhoto,
                  onUpload: _uploadPhotos,
                ),
                const SizedBox(height: 18),
                const InfoCallout(
                  message:
                      'After field work is complete, submit one detailed service report for manager review.',
                  icon: Icons.description_outlined,
                  tone: CalloutTone.neutral,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              12,
              AppTheme.gutter,
              12,
            ),
            child: SafeArea(
              top: false,
              child:
                  job.reportReviewStatus ==
                      ReportReviewStatus.correctionRequired
                  ? const SizedBox.shrink()
                  : PrimaryButton(
                      label: 'MARK COMPLETED',
                      icon: Icons.check_circle_outline_rounded,
                      busy: data.busy || _uploadingPhotos,
                      onPressed: _complete,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PendingPhoto {
  const PendingPhoto({
    required this.file,
    required this.bytes,
    required this.contentType,
  });

  final XFile file;
  final Uint8List bytes;
  final String contentType;
}

/// Compact job identity header for the active-work screen.
class JobStrip extends StatelessWidget {
  const JobStrip({super.key, required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.workOrderId.isEmpty ? job.id : job.workOrderId,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  job.serviceType,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge.work(job.status, dense: true),
        ],
      ),
    );
  }
}

/// Photo grid with an add tile (spec §22).
class PhotoPanel extends StatelessWidget {
  const PhotoPanel({
    super.key,
    required this.job,
    required this.pendingPhotos,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadIndex,
    required this.uploadTotal,
    required this.onAdd,
    required this.onRemove,
    required this.onUpload,
  });

  final WorkJob job;
  final List<PendingPhoto> pendingPhotos;
  final bool uploading;
  final double uploadProgress;
  final int uploadIndex;
  final int uploadTotal;
  final Future<void> Function() onAdd;
  final void Function(int) onRemove;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).data.busy || uploading;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${job.photoCount} photo${job.photoCount == 1 ? '' : 's'} '
                'uploaded',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (job.photoUrls.isNotEmpty)
                for (final url in job.photoUrls)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Image.network(
                      url,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  )
              else
                for (var i = 0; i < job.photoCount; i++)
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.muted,
                      size: 22,
                    ),
                  ),
              for (var i = 0; i < pendingPhotos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Image.memory(
                        pendingPhotos[i].bytes,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (!uploading)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              _AddTile(busy: busy, onTap: onAdd),
            ],
          ),
          if (uploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: uploadProgress),
            const SizedBox(height: 5),
            Text(
              'Uploading photo ${uploadIndex + 1} of $uploadTotal',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (pendingPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SecondaryButton(
              label: uploading ? 'UPLOADING PHOTOS' : 'UPLOAD PHOTOS',
              icon: Icons.cloud_upload_outlined,
              onPressed: busy ? null : onUpload,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'At least one photo is required before the work can be marked '
            'completed.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Icon(
          busy ? Icons.hourglass_top_rounded : Icons.add_a_photo_outlined,
          color: busy ? AppColors.hint : AppColors.primary,
          size: 20,
        ),
      ),
    );
  }
}

/// §23 — work closed out.
class _CompletedScreen extends StatelessWidget {
  const _CompletedScreen({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final matches = AppScope.of(context).data.jobs.where((j) => j.id == jobId);

    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Work Completed')),
        body: const Center(
          child: Text('This work order is no longer available.'),
        ),
      );
    }
    final job = matches.first;
    final reportReady =
        job.status == WorkStatus.completed ||
        job.status == WorkStatus.awaitingReport;
    final reportNeedsAction =
        job.report?.id.isNotEmpty != true ||
        job.reportReviewStatus == ReportReviewStatus.draft ||
        job.reportReviewStatus == ReportReviewStatus.correctionRequired;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: AppColors.mintSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                reportReady ? 'Work Completed' : 'Your Assignment Is Complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${job.serviceType} - ${job.customerName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Work ID',
                      value: job.id,
                    ),
                    DetailRow(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      value: '${job.photoCount}',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge.work(job.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (reportReady && reportNeedsAction) ...[
                PrimaryButton(
                  label: job.report?.id.isNotEmpty == true
                      ? 'EDIT SERVICE REPORT'
                      : 'CREATE SERVICE REPORT',
                  icon: Icons.description_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ServiceReportCreateScreen(job: job),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (!reportReady)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'The service report will be available after all assigned technicians finish the field work.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              SecondaryButton(
                label: 'BACK TO MY JOBS',
                icon: Icons.work_rounded,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
