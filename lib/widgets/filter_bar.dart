import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum SortFilter { latest, popular, relevant, quick }

extension SortFilterLabel on SortFilter {
  String get label {
    switch (this) {
      case SortFilter.latest: return 'Latest';
      case SortFilter.popular: return 'Popular';
      case SortFilter.relevant: return 'Relevant';
      case SortFilter.quick: return 'Quick Reads';
    }
  }
}

class FilterIcon extends StatelessWidget {
  final SortFilter selected;
  final ValueChanged<SortFilter> onChanged;
  final ValueChanged<String> onSearch;
  final AppTheme theme;

  const FilterIcon({super.key, required this.selected, required this.onChanged, required this.onSearch, required this.theme});

  void _showPanel(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterPanel(selected: selected, onChanged: onChanged, onSearch: onSearch, theme: theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPanel(context),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.border),
        ),
        child: Icon(Icons.tune_rounded, color: theme.primary, size: 16),
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  final SortFilter selected;
  final ValueChanged<SortFilter> onChanged;
  final ValueChanged<String> onSearch;
  final AppTheme theme;
  const _FilterPanel({required this.selected, required this.onChanged, required this.onSearch, required this.theme});
  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late SortFilter _current;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _current = widget.selected; }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      decoration: BoxDecoration(
        color: t.isKindle ? const Color(0xFFF0E8CF) : const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: t.divider)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 3,
          decoration: BoxDecoration(color: t.muted, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 24),

        Text('Search', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.border)),
          child: TextField(
            controller: _ctrl,
            style: GoogleFonts.inter(fontSize: 14, color: t.primary),
            cursorColor: t.primary,
            decoration: InputDecoration(
              hintText: 'Search stories...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: t.muted),
              prefixIcon: Icon(Icons.search_rounded, color: t.muted, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (val) { widget.onSearch(val); Navigator.pop(context); },
          ),
        ),
        const SizedBox(height: 28),

        Text('Sort by', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: t.muted, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        ...SortFilter.values.map((filter) {
          final isSelected = filter == _current;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _current = filter);
              widget.onChanged(filter);
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? t.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Text(filter.label, style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? t.primary : t.secondary,
                )),
                const Spacer(),
                if (isSelected) Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.primary)),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}
