import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

void showAddGameSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.parchment50,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Add a game',
                style:
                    GoogleFonts.literata(fontSize: 22, color: AppColors.ink500)),
          ),
          ListTile(
            leading:
                const Icon(Icons.qr_code_scanner, color: AppColors.clay400),
            title: Text('Scan barcode',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontWeight: FontWeight.w600, color: AppColors.ink500)),
            subtitle: Text('Use your camera to scan a game',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 12, color: AppColors.ink300)),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/library/scanner');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search, color: AppColors.clay400),
            title: Text('Search by title',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontWeight: FontWeight.w600, color: AppColors.ink500)),
            subtitle: Text('Find a game on BoardGameGeek',
                style: GoogleFonts.atkinsonHyperlegibleNext(
                    fontSize: 12, color: AppColors.ink300)),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/library/manual-add');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
