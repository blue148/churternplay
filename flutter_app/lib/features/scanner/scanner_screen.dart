import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/services/games_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  String? _statusMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _statusMessage = 'Looking up barcode…';
    });

    try {
      // 1. Check if game already exists in shared DB
      Game? game = await GamesService.getGameByBarcode(barcode);

      if (game == null) {
        setState(() => _statusMessage = 'Searching game database…');
        // 2. Call edge function to look up via GameUPC / fallbacks
        final result = await GamesService.lookupBarcode(barcode);
        if (result != null) {
          final bggId = result['bgg_id'] as int?;
          if (bggId != null) {
            setState(() => _statusMessage = 'Fetching game details…');
            // 3. Enrich from BGG
            final bggData = await GamesService.lookupBggById(bggId);
            if (bggData != null) {
              game = await GamesService.upsertSharedGame({
                'barcode': barcode,
                'bgg_id': bggId,
                'name': bggData['name'] ?? result['name'],
                'cover_image': bggData['cover_image'],
                'min_players': bggData['min_players'],
                'max_players': bggData['max_players'],
                'playtime_minutes': bggData['playtime_minutes'],
                'year': (bggData['year'] as int?)?.toString(),
                'game_category': bggData['game_category'] ?? [],
                'game_mechanic': bggData['game_mechanic'] ?? [],
              });
              // 4. Submit barcode mapping back to GameUPC (crowdsourced)
              GamesService.submitBarcodeMapping(barcode, bggId);
            }
          } else if (result['name'] != null) {
            // No BGG ID from GameUPC (e.g. token unavailable) — search BGG
            // by the title we did get, to enrich with full game details
            // before falling back to a bare entry.
            setState(() => _statusMessage = 'Matching with BoardGameGeek…');
            Map<String, dynamic>? bggData;
            int? matchedBggId;
            try {
              final searchResults =
                  await GamesService.searchBgg(result['name'] as String);
              matchedBggId = searchResults.isNotEmpty
                  ? searchResults.first['bgg_id'] as int?
                  : null;
              if (matchedBggId != null) {
                bggData = await GamesService.lookupBggById(matchedBggId);
              }
            } catch (_) {
              // BGG search/lookup failed — fall back to the bare entry below.
            }

            if (bggData != null && matchedBggId != null) {
              game = await GamesService.upsertSharedGame({
                'barcode': barcode,
                'bgg_id': matchedBggId,
                'name': bggData['name'] ?? result['name'],
                'cover_image': bggData['cover_image'],
                'min_players': bggData['min_players'],
                'max_players': bggData['max_players'],
                'playtime_minutes': bggData['playtime_minutes'],
                'year': (bggData['year'] as int?)?.toString(),
                'game_category': bggData['game_category'] ?? [],
                'game_mechanic': bggData['game_mechanic'] ?? [],
              });
              GamesService.submitBarcodeMapping(barcode, matchedBggId);
            } else {
              // No BGG match either — create minimal entry from barcode lookup
              game = await GamesService.upsertSharedGame({
                'barcode': barcode,
                'name': result['name'],
                'publisher': result['brand'],
              });
            }
          }
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

      // 5. Add to user's library
      setState(() => _statusMessage = 'Adding to library…');
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await GamesService.addGameToLibrary(user.id, game.id);
        await ref.read(libraryProvider.notifier).refresh();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${game.name} added to your library',
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
                        extra: barcode,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan Game',
            style: GoogleFonts.literata(color: Colors.white, fontSize: 22)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _handleBarcode(barcode!.rawValue!);
              }
            },
          ),

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
        ],
      ),
    );
  }
}
