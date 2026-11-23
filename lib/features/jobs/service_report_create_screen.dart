import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';

class ServiceReportCreateScreen extends StatefulWidget {
  const ServiceReportCreateScreen({super.key, required this.job});

  final WorkJob job;

  @override
  State<ServiceReportCreateScreen> createState() =>
      _ServiceReportCreateScreenState();
}

class _ServiceReportCreateScreenState extends State<ServiceReportCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _performed = TextEditingController();
  final _issues = TextEditingController();
  final _materials = TextEditingController();
  final _recommendations = TextEditingController();
  final _remarks = TextEditingController();
  final _caption = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<PendingReportPhoto> _pendingPhotos = [];
  final List<WorkPhoto> _uploadedPhotos = [];
  final List<WorkPhotoUploadFailure> _uploadFailures = [];
  final Set<String> _removedPhotoIds = {};
  String? _reportId;
  bool _initialized = false;
  bool _busy = false;
  bool _uploadingPhotos = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  ServiceReport? get _report => widget.job.report;

  bool get _readOnly {
    if (widget.job.reportReviewStatus == ReportReviewStatus.draft ||
        widget.job.reportReviewStatus ==
            ReportReviewStatus.correctionRequired) {
      return false;
    }
    if (widget.job.reportReviewStatus == ReportReviewStatus.approved ||
        widget.job.reportReviewStatus == ReportReviewStatus.pendingReview) {
      return true;
    }
    if (_reportId != null && _reportId!.isNotEmpty) {
      return !(_report?.canEdit ?? false);
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final report = _report;
    _reportId = report?.id.isNotEmpty == true ? report!.id : null;
    _summary.text = report?.workSummary ?? '';
    _performed.text = report?.workPerformed ?? widget.job.serviceReport;
    _issues.text = report?.issuesFound ?? '';
    _materials.text = report?.materialsUsed ?? '';
    _recommendations.text = report?.recommendations ?? '';
    _remarks.text = report?.completionRemarks ?? '';
  }

  @override
  void dispose() {
    _summary.dispose();
    _performed.dispose();
    _issues.dispose();
    _materials.dispose();
    _recommendations.dispose();
    _remarks.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<String?> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return null;
    if ((_report == null || _report!.id.isEmpty) &&
        (widget.job.reportReviewStatus == ReportReviewStatus.draft ||
            widget.job.reportReviewStatus ==
                ReportReviewStatus.correctionRequired)) {
      _showMessage(
        'The existing report details are incomplete, so it cannot be updated safely.',
      );
      return null;
    }
    final result = await AppScope.read(context).saveEmployeeServiceReport(
      workOrderId: widget.job.id,
      reportId: _reportId,
      workSummary: _summary.text,
      workPerformed: _performed.text,
      issuesFound: _issues.text,
      materialsUsed: _materials.text,
      recommendations: _recommendations.text,
      completionRemarks: _remarks.text,
    );
    if (!mounted) return null;
    if (result case Failure<Map<String, dynamic>>(:final message)) {
      _showMessage(message);
      return null;
    }

    final response = (result as Success<Map<String, dynamic>>).value;
    if (_reportId == null) {
      final savedId = _findReportId(response);
      if (savedId != null && mounted) {
        setState(() => _reportId = savedId);
      }
    }
    if (_reportId == null || _reportId!.isEmpty) {
      _showMessage(
        'The report was saved, but the server did not return its report ID.',
      );
      return null;
    }
    return _reportId;
  }

  String? _findReportId(Map<String, dynamic> response) {
    for (final key in const ['id', '_id', 'serviceReportId', 'reportId']) {
      final value = response[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    for (final key in const ['report', 'serviceReport', 'data']) {
      final nested = response[key];
      if (nested is Map) {
        final found = _findReportId(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _pickPhotos() async {
    if (_readOnly || _busy) return;
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
      final List<XFile> files;
      if (source == ImageSource.camera) {
        final file = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        files = file == null ? const <XFile>[] : [file];
      } else {
        files = await _imagePicker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
      }
      if (!mounted || files.isEmpty) return;
      final picked = <PendingReportPhoto>[];
      final unsupported = <String>[];
      for (final file in files) {
        final contentType = _contentType(file);
        if (contentType == null) {
          unsupported.add(file.name);
          continue;
        }
        final bytes = await file.readAsBytes();
        picked.add(
          PendingReportPhoto(
            upload: WorkPhotoUploadFile(
              fileName: file.name,
              bytes: bytes,
              contentType: contentType,
            ),
            previewBytes: bytes,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _pendingPhotos.addAll(picked));
      if (unsupported.isNotEmpty) {
        _showMessage(
          'Unsupported photo format: ${unsupported.join(', ')}. '
          'Choose JPEG, PNG, or WEBP images.',
        );
      }
      // Persist picked evidence immediately. If the report draft does not
      // exist yet, the backend links these work-order photos when the draft is
      // created later.
      if (picked.isNotEmpty) await _uploadPhotos();
    } catch (error) {
      if (mounted) {
        _showMessage('Could not access the camera or gallery: $error');
      }
    }
  }

  String? _contentType(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      return mime;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  Future<void> _uploadPhotos() async {
    if (_pendingPhotos.isEmpty || _uploadingPhotos) return;
    setState(() {
      _uploadingPhotos = true;
      _uploadProgress = 0;
      _uploadTotal = _pendingPhotos.length;
      _uploadFailures.clear();
    });
    final reportId = _reportId;

    var stoppedOnFailure = false;
    while (_pendingPhotos.isNotEmpty && mounted) {
      final batch = _pendingPhotos.take(10).toList();
      final result = await AppScope.read(context).uploadWorkReportPhotos(
        workOrderId: widget.job.id,
        serviceReportId: reportId,
        caption: _caption.text,
        files: batch.map((photo) => photo.upload).toList(),
      );
      if (!mounted) return;
      if (result case Failure<WorkPhotoUploadResult>(:final message)) {
        _showMessage(message);
        stoppedOnFailure = true;
        break;
      }

      final response = (result as Success<WorkPhotoUploadResult>).value;
      if (response.photos.isEmpty && response.failures.isEmpty) {
        _showMessage(
          'The server did not return uploaded photo details. '
          'Photos remain selected so you can retry.',
        );
        stoppedOnFailure = true;
        break;
      }
      for (final photo in response.photos) {
        if (!_uploadedPhotos.any(
          (existing) =>
              existing.id.isNotEmpty && existing.id == photo.id ||
              existing.imageUrl == photo.imageUrl,
        )) {
          _uploadedPhotos.add(photo);
        }
      }
      if (response.failures.isEmpty) {
        setState(() {
          _pendingPhotos.removeRange(0, batch.length);
          _uploadProgress += batch.length;
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
            (name) => batch.any((photo) => photo.upload.fileName == name),
          );
      if (canMapFailures) {
        setState(() {
          _uploadFailures.addAll(response.failures);
          _pendingPhotos.removeWhere(
            (photo) => !failedNames.contains(photo.upload.fileName),
          );
          _uploadProgress += batch.length - failedNames.length;
        });
      } else {
        setState(() => _uploadFailures.addAll(response.failures));
      }
      _showMessage(
        response.failures
            .map(
              (failure) => failure.fileName.isEmpty
                  ? failure.message
                  : '${failure.fileName}: ${failure.message}',
            )
            .join('\n'),
      );
      stoppedOnFailure = true;
      break;
    }
    if (mounted) {
      setState(() => _uploadingPhotos = false);
      if (!stoppedOnFailure && _pendingPhotos.isEmpty) {
        _showMessage('All selected photos uploaded.');
      }
    }
  }

  Future<void> _save({required bool submit}) async {
    if (_readOnly || _busy) return;
    setState(() => _busy = true);
    try {
      final id = await _saveDraft();
      if (!mounted || id == null) return;
      if (_pendingPhotos.isNotEmpty) {
        await _uploadPhotos();
        if (!mounted || _pendingPhotos.isNotEmpty) return;
      }
      if (submit) {
        final result = await AppScope.read(
          context,
        ).submitEmployeeServiceReport(id);
        if (!mounted) return;
        if (result case Failure<bool>(:final message)) {
          _showMessage(message);
          return;
        }
        _showMessage('Report submitted for review.');
      } else {
        _showMessage('Draft saved.');
      }
      await AppScope.read(context).refresh();
      if (!mounted) return;
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeUploadedPhoto(WorkPhoto photo) async {
    final reportId = _reportId;
    if (photo.id.isEmpty || reportId == null || _busy || _uploadingPhotos) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove report photo?'),
        content: const Text(
          'This photo will be removed from the report before it is resubmitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await AppScope.read(
        context,
      ).removeWorkReportPhoto(photo.id);
      if (!mounted) return;
      if (result case Failure<bool>(:final message)) {
        _showMessage(message);
        return;
      }
      setState(() => _removedPhotoIds.add(photo.id));
      _showMessage(
        'Photo removed from the report. Add a replacement or resubmit.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  void _showPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(32),
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final readOnly = _readOnly;
    final isCorrection =
        widget.job.reportReviewStatus == ReportReviewStatus.correctionRequired;
    final title = _reportId == null
        ? 'Create Service Report'
        : 'Service Report';
    final photos = <WorkPhoto>[
      ...?report?.photos,
      ..._uploadedPhotos,
      ...widget.job.photoUrls.map(
        (url) => WorkPhoto(imageUrl: ApiConfig.resolveMediaUrl(url)),
      ),
    ];
    final photoByUrl = <String, WorkPhoto>{};
    for (final photo in photos) {
      if (photo.imageUrl.isNotEmpty) {
        photoByUrl.putIfAbsent(photo.imageUrl, () => photo);
      }
    }
    final uniquePhotos = photoByUrl.values
        .where((photo) => !_removedPhotoIds.contains(photo.id))
        .toList();
    final reviewResult = report?.reviewResult.isNotEmpty == true
        ? report!.reviewResult
        : widget.job.reportReviewResult;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Work order ${widget.job.workOrderId.isEmpty ? widget.job.id : widget.job.workOrderId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_reportId != null ||
                      widget.job.reportReviewStatus !=
                          ReportReviewStatus.notSubmitted) ...[
                    const SizedBox(height: 10),
                    Chip(
                      label: Text(
                        _reportId != null &&
                                widget.job.reportReviewStatus ==
                                    ReportReviewStatus.notSubmitted
                            ? ReportReviewStatus.draft.label
                            : report?.status.isNotEmpty == true
                            ? report!.status
                            : widget.job.reportReviewStatus.label,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isCorrection && widget.job.correctionNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              InfoCallout(
                message: 'Correction requested: ${widget.job.correctionNote}',
                icon: Icons.edit_note_rounded,
                tone: CalloutTone.warning,
              ),
            ],
            if (readOnly && reviewResult.isNotEmpty) ...[
              const SizedBox(height: 12),
              InfoCallout(
                message: 'Review result: $reviewResult',
                icon: Icons.fact_check_outlined,
                tone: CalloutTone.neutral,
              ),
            ],
            if (readOnly) ...[
              const SizedBox(height: 12),
              InfoCallout(
                message:
                    widget.job.reportReviewStatus == ReportReviewStatus.approved
                    ? 'This report has been approved and is read-only.'
                    : 'This report is awaiting supervisor review.',
                icon: Icons.lock_outline_rounded,
                tone: CalloutTone.neutral,
              ),
            ],
            const SizedBox(height: 18),
            _field(
              _summary,
              'Work summary',
              required: true,
              readOnly: readOnly,
            ),
            _field(
              _performed,
              'Work performed',
              required: true,
              lines: 4,
              readOnly: readOnly,
            ),
            _field(_issues, 'Issues found', lines: 3, readOnly: readOnly),
            _field(_materials, 'Materials used', lines: 3, readOnly: readOnly),
            _field(
              _recommendations,
              'Recommendations',
              lines: 3,
              readOnly: readOnly,
            ),
            _field(
              _remarks,
              'Completion remarks',
              lines: 3,
              readOnly: readOnly,
            ),
            const SizedBox(height: 8),
            const SectionHeader(title: 'Report Photos'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (uniquePhotos.isEmpty && _pendingPhotos.isEmpty)
                    const Text(
                      'No report photos yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final photo in uniquePhotos)
                        Stack(
                          children: [
                            _photoTile(
                              photo.previewUrl,
                              onTap: () => _showPhoto(photo.imageUrl),
                            ),
                            if (!readOnly &&
                                isCorrection &&
                                photo.id.isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove photo',
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: _busy || _uploadingPhotos
                                      ? null
                                      : () => _removeUploadedPhoto(photo),
                                ),
                              ),
                          ],
                        ),
                      for (final photo in _pendingPhotos)
                        Stack(
                          children: [
                            _photoTile(
                              null,
                              bytes: photo.previewBytes,
                              onTap: () {},
                            ),
                            if (!_uploadingPhotos && !readOnly)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: () => setState(
                                    () => _pendingPhotos.remove(photo),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (!readOnly)
                        InkWell(
                          onTap: _busy || _uploadingPhotos ? null : _pickPhotos,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                    ],
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _caption,
                      enabled: !_busy && !_uploadingPhotos,
                      decoration: const InputDecoration(
                        labelText: 'Photo caption (optional)',
                      ),
                    ),
                    if (_uploadingPhotos) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _uploadTotal == 0
                            ? null
                            : _uploadProgress / _uploadTotal,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Uploading ${_uploadProgress.clamp(0, _uploadTotal)} '
                        'of $_uploadTotal photos',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (_uploadFailures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final failure in _uploadFailures)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            failure.fileName.isEmpty
                                ? failure.message
                                : '${failure.fileName}: ${failure.message}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    if (_pendingPhotos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: _uploadingPhotos
                            ? 'UPLOADING PHOTOS'
                            : 'UPLOAD / RETRY PHOTOS',
                        icon: Icons.cloud_upload_outlined,
                        onPressed: _busy || _uploadingPhotos
                            ? null
                            : _uploadPhotos,
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Images are resized and compressed on this device when supported.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: isCorrection
                    ? 'RESUBMIT FOR REVIEW'
                    : 'SUBMIT FOR REVIEW',
                icon: Icons.send_rounded,
                busy: _busy,
                onPressed: _busy || _uploadingPhotos
                    ? null
                    : () => _save(submit: true),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'SAVE DRAFT',
                icon: Icons.save_outlined,
                onPressed: _busy || _uploadingPhotos
                    ? null
                    : () => _save(submit: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      validator: required && !readOnly
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );

  Widget _photoTile(
    String? url, {
    Uint8List? bytes,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: bytes != null
          ? Image.memory(bytes, width: 76, height: 76, fit: BoxFit.cover)
          : Image.network(
              url!,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 76,
                height: 76,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
    ),
  );
}

class PendingReportPhoto {
  const PendingReportPhoto({required this.upload, required this.previewBytes});

  final WorkPhotoUploadFile upload;
  final Uint8List previewBytes;
}
