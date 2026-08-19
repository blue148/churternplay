import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/services/games_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';

/// Add a game to the library by searching BoardGameGeek by title.
///
/// Mirrors the web app's ManualGameEntry flow: search BGG → pick a result →
/// fetch full details → de-dupe by bgg_id → upsert into shared_games →
/// add to the user's library.
///
/// [barcode] is optional. When the scanner fails to identify a barcode it can
/// route here with the scanned value so the resulting game keeps that barcode.
class ManualGameEntryPage extends ConsumerStatefulWidget {
  const ManualGameEntryPage({super.key, this.barcode});

  final String? barcode;

  @override
  ConsumerState<ManualGameEntryPage> createState() =>
      _ManualGameEntryPageState();
}

class _ManualGameEntryPageState extends ConsumerState<ManualGameEntryPage> {
  final _searchCtrl = TextEditingController();

  bool _searching = false;
  bool _loadingDetails = false;
  bool _adding = false;
  String? _error;

  List<Map<String, dynamic>> _results = [];
  int? _selectedBggId;
  Map<String, dynamic>? _selectedGame;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a game name to search.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
      _selectedGame = null;
      _selectedBggId = null;
    });

    try {
      final results = await GamesService.searchBgg(query);
      _sortResults(results, query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = results.isEmpty
            ? 'No games found. Try a different search term.'
            : null;
      });
    } catch (e, st) {
      debugPrint('BGG search failed: $e\n$st');
      if (!mounted) return;
      setState(() => _error = 'Failed to search BoardGameGeek. Please try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Prioritise exact matches, then prefix matches, then newer years —
  /// matches the web app's searchBggGames sort.
  void _sortResults(List<Map<String, dynamic>> results, String query) {
    final q = query.toLowerCase();
    results.sort((a, b) {
      final an = (a['name'] as String? ?? '').toLowerCase();
      final bn = (b['name'] as String? ?? '').toLowerCase();

      final aExact = an == q;
      final bExact = bn == q;
      if (aExact != bExact) return aExact ? -1 : 1;

      final aStarts = an.startsWith(q);
      final bStarts = bn.startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      final ay = (a['year'] as int?) ?? 0;
      final by = (b['year'] as int?) ?? 0;
      return by - ay;
    });
  }

  Future<void> _selectResult(Map<String, dynamic> result) async {
    final bggId = result['bgg_id'] as int?;
    if (bggId == null) return;

    setState(() {
      _loadingDetails = true;
      _error = null;
      _selectedBggId = bggId;
    });

    try {
      final details = await GamesService.lookupBggById(bggId);
      if (!mounted) return;
      setState(() {
        _selectedGame = details;
        _results = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load game details. Please try again.';
        _selectedBggId = null;
      });
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _addToLibrary() async {
    final details = _selectedGame;
    final bggId = _selectedBggId;
    if (details == null || bggId == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      // De-dupe by BGG id so the same game with different barcodes maps to one
      // shared_games row.
      Game? game = await GamesService.getGameByBggId(bggId);

      game ??= await GamesService.upsertSharedGame({
        // Manual entries have no scanned barcode; generate a stable placeholder
        // so the unique barcode column is satisfied without colliding.
        'barcode': widget.barcode ??
            'MANUAL-$bggId-${DateTime.now().millisecondsSinceEpoch}',
        'bgg_id': bggId,
        'name': details['name'],
        'publisher': details['publisher'],
        'year': (details['year'] as int?)?.toString(),
        'cover_image': details['cover_image'],
        'min_players': details['min_players'],
        'max_players': details['max_players'],
        'playtime_minutes': details['playtime_minutes'],
        'game_type': details['game_type'] ?? [],
        'game_category': details['game_category'] ?? [],
        'game_mechanic': details['game_mechanic'] ?? [],
      });

      await GamesService.addGameToLibrary(user.id, game.id);
      await ref.read(libraryProvider.notifier).refresh();

      // Crowdsource the barcode → BGG mapping when we have a real barcode.
      if (widget.barcode != null) {
        GamesService.submitBarcodeMapping(widget.barcode!, bggId);
      }

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = 'Failed to add game. Please try again.';
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedGame = null;
      _selectedBggId = null;
      _results = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment50,
      appBar: AppBar(
        title: const Text('Add a Game'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.barcode != null) _barcodeNotice(),
          if (_selectedGame == null) _searchField(),
          if (_error != null) _errorBox(_error!),
          if (_loadingDetails) _loadingDetailsRow(),
          if (_selectedGame == null && _results.isNotEmpty) _resultsList(),
          if (_selectedGame != null) _preview(_selectedGame!),
        ],
      ),
    );
  }

  Widget _barcodeNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.wheat100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.wheat200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We couldn't match that barcode. Search for the game below.",
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink400),
          ),
          const SizedBox(height: 4),
          Text(
            'Barcode: ${widget.barcode}',
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 12,
                color: AppColors.ink300,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              enabled: !_searching,
              decoration: InputDecoration(
                hintText: 'e.g. Ticket to Ride',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: AppColors.ink200),
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
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _searching ? null : _search,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clay400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Search'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.clay50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.clay100),
      ),
      child: Text(
        message,
        style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.clay500),
      ),
    );
  }

  Widget _loadingDetailsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Loading game details…',
              style: GoogleFonts.atkinsonHyperlegibleNext(color: AppColors.ink300)),
        ],
      ),
    );
  }

  Widget _resultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Select your game',
            style: GoogleFonts.atkinsonHyperlegibleNext(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink400)),
        const SizedBox(height: 8),
        ..._results.map((r) {
          final year = r['year'] as int?;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.ink100),
            ),
            child: ListTile(
              title: Text(r['name'] as String? ?? 'Unknown',
                  style: GoogleFonts.atkinsonHyperlegibleNext(
                      fontWeight: FontWeight.w600, color: AppColors.ink500)),
              subtitle: Text(
                year != null ? 'Published $year' : 'Year unknown',
                style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 12, color: AppColors.ink300),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.ink200),
              onTap: _loadingDetails ? null : () => _selectResult(r),
            ),
          );
        }),
      ],
    );
  }

  Widget _preview(Map<String, dynamic> game) {
    final name = game['name'] as String? ?? 'Unknown';
    final year = game['year'] as int?;
    final publisher = game['publisher'] as String?;
    final cover = game['cover_image'] as String?;
    final minP = game['min_players'] as int?;
    final maxP = game['max_players'] as int?;
    final playtime = game['playtime_minutes'] as int?;
    final minAge = game['min_age'] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cover != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 88,
                          height: 88,
                          color: AppColors.parchment100,
                          child: const Icon(Icons.casino_outlined,
                              color: AppColors.ink200),
                        ),
                      ),
                    ),
                  if (cover != null) const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.literata(
                                fontSize: 22, color: AppColors.ink500)),
                        if (year != null)
                          Text('Published $year',
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 13, color: AppColors.ink300)),
                        if (publisher != null)
                          Text(publisher,
                              style: GoogleFonts.atkinsonHyperlegibleNext(
                                  fontSize: 13, color: AppColors.ink300)),
                      ],
                    ),
                  ),
                ],
              ),
              if (minP != null || maxP != null || playtime != null ||
                  minAge != null) ...[
                const Divider(height: 24, color: AppColors.ink100),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (minP != null || maxP != null)
                      _stat(Icons.people_outline, _playerLabel(minP, maxP)),
                    if (playtime != null)
                      _stat(Icons.schedule, '$playtime min'),
                    if (minAge != null) _stat(Icons.cake_outlined, '$minAge+'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _adding ? null : _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Search Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _adding ? null : _addToLibrary,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add, size: 20),
                label: const Text('Add to Library'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.ink300),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.atkinsonHyperlegibleNext(fontSize: 13, color: AppColors.ink400)),
      ],
    );
  }

  String _playerLabel(int? min, int? max) {
    if (min != null && max != null) {
      return min == max ? '$min players' : '$min–$max players';
    }
    return '${min ?? max} players';
  }
}
