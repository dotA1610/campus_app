import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_helper.dart';

class ApplyLeaveDocumentsPage extends StatefulWidget {
  final String leaveType;
  final List<Map<String, String>> uploadedDocs; // [{name,url}]
  final ValueChanged<List<Map<String, String>>> onChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const ApplyLeaveDocumentsPage({
    super.key,
    required this.leaveType,
    required this.uploadedDocs,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<ApplyLeaveDocumentsPage> createState() => _ApplyLeaveDocumentsPageState();
}

class _ApplyLeaveDocumentsPageState extends State<ApplyLeaveDocumentsPage> {
  bool uploading = false;
  String? error;

  Future<void> _pickAndUploadMultiple() async {
    if (uploading) return;

    setState(() {
      uploading = true;
      error = null;
    });

    try {
      final profile = await getMyProfile();
      final studentId = (profile['student_id'] ?? '').toString().trim();
      if (studentId.isEmpty) {
        throw "student_id is empty in profiles table.";
      }

      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (res == null || res.files.isEmpty) {
        if (mounted) setState(() => uploading = false);
        return;
      }

      final newDocs = List<Map<String, String>>.from(widget.uploadedDocs);

      for (final f in res.files) {
        final Uint8List? bytes = f.bytes;
        if (bytes == null) continue;

        final originalName = f.name.trim();
        final safeName =
            originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

        final ext = (f.extension ?? '').toLowerCase();
        if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) continue;

        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = '$studentId/${widget.leaveType}/$ts\_$safeName';

        // ✅ IMPORTANT: FileOptions comes from supabase_flutter
        // (If your version complains, see notes below.)
        await supabase.storage.from('leave').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: false),
            );

        final publicUrl = supabase.storage.from('leave').getPublicUrl(path);

        newDocs.add({
          'name': originalName,
          'url': publicUrl,
        });
      }

      widget.onChanged(newDocs);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Uploaded ${res.files.length} file(s) ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _removeAt(int index) {
    final list = List<Map<String, String>>.from(widget.uploadedDocs);
    list.removeAt(index);
    widget.onChanged(list);
  }

  Color _muted(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card = cs.surface;
    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final onCard = cs.onSurface;

    Widget cardWrap({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        cardWrap(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.upload_file, color: onCard),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Supporting Documents",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: onCard,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Upload PDF/JPG/PNG (multiple supported).",
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: uploading ? null : _pickAndUploadMultiple,
                icon: const Icon(Icons.add),
                label: Text(uploading ? "Uploading..." : "Add Files"),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (widget.uploadedDocs.isEmpty)
          cardWrap(
            child: Text(
              "No files uploaded yet.",
              style: TextStyle(color: _muted(context)),
            ),
          )
        else
          ...List.generate(widget.uploadedDocs.length, (i) {
            final doc = widget.uploadedDocs[i];
            final name = (doc['name'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: cardWrap(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: _muted(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: onCard),
                      ),
                    ),
                    IconButton(
                      onPressed: uploading ? null : () => _removeAt(i),
                      icon: Icon(Icons.close, color: _muted(context)),
                      tooltip: "Remove",
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: uploading ? null : widget.onBack,
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: uploading ? null : widget.onContinue,
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}