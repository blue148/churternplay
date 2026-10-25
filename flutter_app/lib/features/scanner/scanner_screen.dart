import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/services/games_service.dart';
import '../../data/services/text_recognition_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../library/manual_game_entry_page.dart';
import 'retail_title.dart';
import 'title_extractor.dart';

enum _ScanMode { barcode, title }

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  // Opens in box-title mode, so the barcode camera only starts when the user
  // switches to it.
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );

  _ScanMode _mode = _ScanMode.title;
  bool _processing = false;
  String? _statusMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(_ScanMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    // Release the camera in title mode so the system camera can use it.
    if (mode == _ScanMode.title) {
      _controller.stop();
    } else {
      _controller.start();
    }
  }

  // ── Barcode mode ───────────────────────────────────────────────────────────

  Future<void> _handleBarcode(String barcode) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _statusMessage = 'Looking up barcode…';
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
        return;
      }

      Game? game;
      var alreadyInLibrary = false;

      // 1. Check if game already exists in shared DB
      final existing = await GamesService.getGameByBarcode(barcode);

      if (existing != null) {
        setState(() => _statusMessage = 'Adding to library…');
        game = existing;
        try {
          await GamesService.addGameToLibrary(user.id, existing.id);
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow; // unique_violation
          alreadyInLibrary = true;
        }
      } else {
        setState(() => _statusMessage = 'Searching game database…');
        // 2. Call edge function to look up via GameUPC / fallbacks
        final result = await GamesService.lookupBarcode(barcode);
        final name = result?['name'] as String?;
        final bggId = result?['bgg_id'] as int?;

        if (bggId != null) {
          setState(() => _statusMessage = 'Adding to library…');
          // 3. Create the shared game server-side from BGG and add it to the
          //    library.
          final added = await GamesService.addGameToLibraryFromBgg(
            bggId: bggId,
            barcode: barcode,
          );
          game = added.game;
          alreadyInLibrary = added.alreadyInLibrary;
          // 4. Submit barcode mapping back to GameUPC (crowdsourced)
          GamesService.submitBarcodeMapping(barcode, bggId);
        } else if (name != null) {
          // A product name but no BGG ID (a fallback lookup service). Those are
          // shop listing titles, so let the user confirm the match on the
          // search-by-title page, which keeps the barcode and submits the
          // mapping once they pick.
          if (!mounted) return;
          context.pushReplacement(
            '/library/manual-add',
            extra: ManualAddArgs(
              barcode: barcode,
              initialQuery: cleanRetailTitle(name),
            ),
          );
          return;
        }
      }

      if (game == null) {
        setState(() {
          _statusMessage = null;
          _processing = false;
        });
        _showNotFound(barcode);
        return;
      }

      await ref.read(libraryProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alreadyInLibrary
                  ? '${game.name} is already in your library'
                  : '${game.name} added to your library',
              style: GoogleFonts.atkinsonHyperlegibleNext(),
            ),
            backgroundColor: AppColors.forest500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.atkinsonHyperlegibleNext()),
            backgroundColor: AppColors.clay500,
          ),
        );
      }
    }
  }

  void _showNotFound(String barcode) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.ink200),
            const SizedBox(height: 12),
            Text('Game not found', style: GoogleFonts.literata(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Barcode $barcode is not in the database yet.',
              style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink300),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Scan Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context); // close the bottom sheet
                      // Leave the scanner and open manual entry, carrying the
                      // unmatched barcode so the saved game keeps it.
                      context.pushReplacement(
                        '/library/manual-add',
                        extra: ManualAddArgs(barcode: barcode),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.forest500),
                    child: const Text('Add Manually'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Box title mode ─────────────────────────────────────────────────────────

  Future<void> _pickBoxPhoto(ImageSource source) async {
    if (_processing) return;

    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } catch (e) {
      _showError("Couldn't open the ${source == ImageSource.camera ? 'camera' : 'photo library'}.");
      return;
    }
    if (photo == null || !mounted) return;

    setState(() {
      _processing = true;
      _statusMessage = 'Reading title…';
    });

    List<String> candidates;
    try {
      final lines = await TextRecognitionService.recognize(photo.path);
      candidates = extractTitleCandidates(lines);
    } catch (e) {
      debugPrint('Text recognition failed: $e');
      candidates = const [];
    }

    if (!mounted) return;
    setState(() {
      _processing = false;
      _statusMessage = null;
    });

    if (candidates.isEmpty) {
      _deletePhoto(photo.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't read a title. Try again or type it.",
              style: GoogleFonts.atkinsonHyperlegibleNext()),
          backgroundColor: AppColors.clay500,
          action: SnackBarAction(
            label: 'Type it',
            textColor: Colors.white,
            onPressed: () => context.pushReplacement('/library/manual-add'),
          ),
        ),
      );
      return;
    }

    final confirmed = await _confirmTitle(candidates, photo.path);
    _deletePhoto(photo.path);
    if (!mounted) return;

    switch (confirmed) {
      case _TitleConfirmed(:final name):
        context.pushReplacement(
          '/library/manual-add',
          extra: ManualAddArgs(initialQuery: name),
        );
      case _TitleRetake():
        _pickBoxPhoto(source);
      case null:
        break;
    }
  }

  Future<_TitleDecision?> _confirmTitle(
      List<String> candidates, String photoPath) {
    return showModalBottomSheet<_TitleDecision>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TitleConfirmSheet(
        photoPath: photoPath,
        candidates: candidates,
      ),
    );
  }

  void _deletePhoto(String path) {
    // image_picker writes picks to the app's temp/cache dir; don't let box
    // photos pile up there.
    File(path).delete().ignore();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.atkinsonHyperlegibleNext()),
        backgroundColor: AppColors.clay500,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan Game',
            style: GoogleFonts.literata(color: Colors.white, fontSize: 22)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _modeToggle(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Kept mounted in both modes; stopped while in title mode.
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_mode != _ScanMode.barcode) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _handleBarcode(barcode!.rawValue!);
              }
            },
          ),

          if (_mode == _ScanMode.barcode) ..._barcodeOverlay(),
          if (_mode == _ScanMode.title) _titleModeBody(),

          // Status / processing overlay
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage ?? 'Processing…',
                      style: GoogleFonts.atkinsonHyperlegibleNext(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return SegmentedButton<_ScanMode>(
      segments: const [
        ButtonSegment(
          value: _ScanMode.title,
          label: Text('Box Title'),
          icon: Icon(Icons.photo_camera_outlined),
        ),
        ButtonSegment(
          value: _ScanMode.barcode,
          label: Text('Barcode'),
          icon: Icon(Icons.qr_code_scanner),
        ),
      ],
      selected: {_mode},
      showSelectedIcon: false,
      onSelectionChanged:
          _processing ? null : (selection) => _setMode(selection.first),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.black : Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.transparent),
        side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.5))),
        textStyle: WidgetStatePropertyAll(
            GoogleFonts.atkinsonHyperlegibleNext(fontSize: 14)),
      ),
    );
  }

  List<Widget> _barcodeOverlay() => [
        // Viewfinder overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Hint text
        if (!_processing)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Point camera at a game barcode',
              textAlign: TextAlign.center,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
      ];

  Widget _titleModeBody() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              'Snap the front of the box',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              "Fill the frame and keep the title clear. We'll read it and "
              'let you check it before searching BoardGameGeek.',
              textAlign: TextAlign.center,
              style: GoogleFonts.atkinsonHyperlegibleNext(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _pickBoxPhoto(ImageSource.camera),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickBoxPhoto(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _TitleDecision {
  const _TitleDecision();
}

class _TitleConfirmed extends _TitleDecision {
  const _TitleConfirmed(this.name);
  final String name;
}

class _TitleRetake extends _TitleDecision {
  const _TitleRetake();
}

/// Shows the title read from the photo for the user to confirm or correct
/// before we search BoardGameGeek.
class _TitleConfirmSheet extends StatefulWidget {
  const _TitleConfirmSheet({
    required this.photoPath,
    required this.candidates,
  });

  final String photoPath;
  final List<String> candidates;

  @override
  State<_TitleConfirmSheet> createState() => _TitleConfirmSheetState();
}

class _TitleConfirmSheetState extends State<_TitleConfirmSheet> {
  late final _nameCtrl = TextEditingController(text: widget.candidates.first)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _TitleConfirmed(name));
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = widget.candidates.skip(1).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(widget.photoPath),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  cacheWidth: 192,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Is this the game?',
                        style: GoogleFonts.literata(fontSize: 22, color: AppColors.ink500)),
                    const SizedBox(height: 4),
                    Text(
                      'Fix the name if we misread it.',
                      style: GoogleFonts.atkinsonHyperlegibleNext(
                          fontSize: 13, color: AppColors.ink300),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              labelText: 'Game name',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.ink100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.ink100),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.clay400),
              ),
            ),
          ),
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Or did you mean',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 12, color: AppColors.ink300)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final alt in alternatives)
                  ChoiceChip(
                    label: Text(alt),
                    selected: _nameCtrl.text == alt,
                    onSelected: (_) => _nameCtrl.text = alt,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const _TitleRetake()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _nameCtrl.text.trim().isEmpty ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Find on BGG'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
