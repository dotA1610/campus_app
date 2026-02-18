import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ IMPORTANT FIX
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
  State<ApplyLeaveDocumentsPage> createState() =>
      _ApplyLeaveDocumentsPageState();
}

class _ApplyLeaveDocumentsPageState
    extends State<ApplyLeaveDocumentsPage> {
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

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
      final studentId =
          (profile['student_id'] ?? '').toString().trim();

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

      final newDocs =
          List<Map<String, String>>.from(widget.uploadedDocs);

      for (final f in res.files) {
        final Uint8List? bytes = f.bytes;
        if (bytes == null) continue;

        final originalName = f.name.trim();
        final safeName = originalName.replaceAll(
            RegExp(r'[^a-zA-Z0-9._-]'), '_');

        final ext = (f.extension ?? '').toLowerCase();
        if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
          continue;
        }

        final ts = DateTime.now().millisecondsSinceEpoch;
        final path =
            '$studentId/${widget.leaveType}/${ts}_$safeName';

        await supabase.storage.from('leave').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
              ), // ✅ now recognized
            );

        final publicUrl =
            supabase.storage.from('leave').getPublicUrl(path);

        newDocs.add({
          'name': originalName,
          'url': publicUrl,
        });
      }

      widget.onChanged(newDocs);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Uploaded ${res.files.length} file(s) ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _removeAt(int index) {
    final list =
        List<Map<String, String>>.from(widget.uploadedDocs);
    list.removeAt(index);
    widget.onChanged(list);
  }

  Widget _cardWrap(
      {required Widget child,
      EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardWrap(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _card2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.upload_file,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Supporting Documents",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Upload PDF/JPG/PNG (multiple supported).",
                      style: TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed:
                    uploading ? null : _pickAndUploadMultiple,
                icon: const Icon(Icons.add),
                label: Text(
                    uploading ? "Uploading..." : "Add Files"),
              )
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (widget.uploadedDocs.isEmpty)
          _cardWrap(
            child: const Text(
              "No files uploaded yet.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...List.generate(widget.uploadedDocs.length,
              (i) {
            final doc = widget.uploadedDocs[i];
            final name =
                (doc['name'] ?? '').toString();

            return Padding(
              padding:
                  const EdgeInsets.only(bottom: 12),
              child: _cardWrap(
                padding:
                    const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file,
                        color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: uploading
                          ? null
                          : () => _removeAt(i),
                      icon: const Icon(Icons.close),
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
                onPressed:
                    uploading ? null : widget.onBack,
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: uploading
                    ? null
                    : widget.onContinue,
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
