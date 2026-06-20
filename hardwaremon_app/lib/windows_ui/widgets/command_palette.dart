import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

class CommandPaletteAction {
  final String id;
  final String title;
  final String description;
  final String section;
  final String? shortcut;
  final IconData icon;
  final List<String> keywords;
  final bool selected;
  final FutureOr<void> Function() run;

  const CommandPaletteAction({
    required this.id,
    required this.title,
    required this.description,
    required this.section,
    required this.icon,
    required this.run,
    this.shortcut,
    this.keywords = const [],
    this.selected = false,
  });

  String get searchText =>
      '$title $description $section ${keywords.join(' ')}'.toLowerCase();
}

Future<void> showHardwareMonCommandPalette({
  required BuildContext context,
  required List<CommandPaletteAction> actions,
  required String systemSummary,
  required String telemetrySummary,
  required Color systemColor,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss command palette',
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => _CommandPaletteDialog(
      actions: actions,
      systemSummary: systemSummary,
      telemetrySummary: telemetrySummary,
      systemColor: systemColor,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.975, end: 1.0).animate(curved),
          alignment: const Alignment(0, -0.55),
          child: child,
        ),
      );
    },
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  final List<CommandPaletteAction> actions;
  final String systemSummary;
  final String telemetrySummary;
  final Color systemColor;

  const _CommandPaletteDialog({
    required this.actions,
    required this.systemSummary,
    required this.telemetrySummary,
    required this.systemColor,
  });

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  List<CommandPaletteAction> get _filteredActions {
    final terms = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return widget.actions;

    return widget.actions
        .where((action) => terms.every(action.searchText.contains))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    final actions = _filteredActions;
    if (actions.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta) % actions.length;
      if (_selectedIndex < 0) _selectedIndex += actions.length;
    });

    if (_scrollController.hasClients) {
      final target = (_selectedIndex * 62.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _runAction(CommandPaletteAction action) async {
    final navigator = Navigator.of(context);
    final callback = action.run;
    navigator.pop();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.sync(callback);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final actions = _filteredActions;
      if (actions.isNotEmpty) {
        _runAction(actions[_selectedIndex.clamp(0, actions.length - 1)]);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _filteredActions;
    if (_selectedIndex >= actions.length && actions.isNotEmpty) {
      _selectedIndex = 0;
    }

    return SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Material(
          color: Colors.transparent,
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Container(
              width: 660,
              constraints: const BoxConstraints(maxHeight: 590),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 60,
                    spreadRadius: 4,
                    offset: const Offset(0, 22),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 90,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSearch(context),
                    Divider(height: 1, color: AppColors.border(context)),
                    Flexible(
                      child: actions.isEmpty
                          ? _buildEmptyState(context)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: actions.length,
                              itemBuilder: (context, index) {
                                final action = actions[index];
                                final showSection =
                                    index == 0 ||
                                    actions[index - 1].section !=
                                        action.section;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showSection)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          11,
                                          20,
                                          6,
                                        ),
                                        child: Text(
                                          action.section.toUpperCase(),
                                          style: TextStyle(
                                            color: AppColors.textMuted(context),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.3,
                                          ),
                                        ),
                                      ),
                                    _CommandRow(
                                      action: action,
                                      selected: index == _selectedIndex,
                                      onHover: () {
                                        if (_selectedIndex != index) {
                                          setState(
                                            () => _selectedIndex = index,
                                          );
                                        }
                                      },
                                      onTap: () => _runAction(action),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    Divider(height: 1, color: AppColors.border(context)),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 21,
                color: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() => _selectedIndex = 0),
                  onSubmitted: (_) {
                    final actions = _filteredActions;
                    if (actions.isNotEmpty) {
                      _runAction(
                        actions[_selectedIndex.clamp(0, actions.length - 1)],
                      );
                    }
                  },
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search pages, telemetry, and actions…',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted(context),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _selectedIndex = 0);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              else
                const _ShortcutChip(label: 'Ctrl K'),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.overlay(context, 0.035),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _LiveDot(color: widget.systemColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.systemSummary,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  widget.telemetrySummary,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 34,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching commands',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            'Try a page name, metric, or action like “pause”.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Text(
            '${_filteredActions.length} commands',
            style: TextStyle(
              color: AppColors.textMuted(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const _FooterHint(keys: '↑↓', label: 'Navigate'),
          const SizedBox(width: 14),
          const _FooterHint(keys: '↵', label: 'Run'),
          const SizedBox(width: 14),
          const _FooterHint(keys: 'Esc', label: 'Close'),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final CommandPaletteAction action;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _CommandRow({
    required this.action,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.22)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.14)
                        : AppColors.overlay(context, 0.045),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    action.icon,
                    size: 18,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action.selected) ...[
                  Icon(Icons.check_rounded, size: 17, color: AppColors.accent),
                  const SizedBox(width: 9),
                ],
                if (action.shortcut != null)
                  _ShortcutChip(label: action.shortcut!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String label;

  const _ShortcutChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  final String keys;
  final String label;

  const _FooterHint({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShortcutChip(label: keys),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
        ),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  final Color color;

  const _LiveDot({required this.color});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(
                alpha: 0.12 + (_controller.value * 0.32),
              ),
              blurRadius: 4 + (_controller.value * 7),
              spreadRadius: _controller.value,
            ),
          ],
        ),
      ),
    );
  }
}
