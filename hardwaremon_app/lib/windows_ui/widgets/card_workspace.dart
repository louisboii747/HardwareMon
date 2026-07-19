import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/card_workspace.dart';

class WorkspaceCard {
  final String id;
  final String title;
  final Widget child;
  final WorkspaceCardSize defaultSize;

  const WorkspaceCard({
    required this.id,
    required this.title,
    required this.child,
    this.defaultSize = WorkspaceCardSize.standard,
  });
}

class CardWorkspace extends StatefulWidget {
  final String pageId;
  final String pageLabel;
  final CardWorkspacePreferences preferences;
  final List<WorkspaceCard> cards;
  final double standardHeight;
  final bool showToolbar;

  const CardWorkspace({
    super.key,
    required this.pageId,
    required this.pageLabel,
    required this.preferences,
    required this.cards,
    this.standardHeight = 250,
    this.showToolbar = true,
  });

  @override
  State<CardWorkspace> createState() => _CardWorkspaceState();
}

class _CardWorkspaceState extends State<CardWorkspace> {
  bool _editing = false;
  String? _draggingId;

  List<String> get _defaults => widget.cards.map((card) => card.id).toList();

  @override
  void initState() {
    super.initState();
    widget.preferences.addListener(_preferencesChanged);
  }

  @override
  void didUpdateWidget(covariant CardWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      oldWidget.preferences.removeListener(_preferencesChanged);
      widget.preferences.addListener(_preferencesChanged);
    }
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_preferencesChanged);
    super.dispose();
  }

  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.preferences.resolve(widget.pageId, _defaults);
    final cardsById = {for (final card in widget.cards) card.id: card};
    final hidden = states.where((state) => !state.visible).toList();
    final visible = states
        .where((state) => state.visible && cardsById.containsKey(state.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showToolbar)
          _WorkspaceToolbar(
            pageLabel: widget.pageLabel,
            editing: _editing,
            hidden: hidden,
            cardsById: cardsById,
            onEditing: () => setState(() => _editing = !_editing),
            onRestore: (id) =>
                widget.preferences.restoreCard(widget.pageId, _defaults, id),
            onReset: () => widget.preferences.resetPage(widget.pageId),
            onLayouts: () => showCardLayoutsDialog(
              context: context,
              preferences: widget.preferences,
            ),
          ),
        if (widget.showToolbar) const SizedBox(height: 12),
        if (visible.isEmpty)
          _EmptyWorkspace(
            onRestore: () => widget.preferences.resetPage(widget.pageId),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 3
                  : constraints.maxWidth >= 680
                  ? 2
                  : 1;
              const gap = 14.0;
              final unitWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var index = 0; index < visible.length; index++)
                    _buildCard(
                      context,
                      visible[index],
                      cardsById[visible[index].id]!,
                      states,
                      unitWidth,
                      columns,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    WorkspaceCardState state,
    WorkspaceCard card,
    List<WorkspaceCardState> allStates,
    double unitWidth,
    int columns,
  ) {
    final size = state.size == WorkspaceCardSize.standard
        ? card.defaultSize
        : state.size;
    final spans = switch (size) {
      WorkspaceCardSize.compact || WorkspaceCardSize.standard => 1,
      WorkspaceCardSize.wide || WorkspaceCardSize.large => 2,
    }.clamp(1, columns);
    final width = unitWidth * spans + 14 * (spans - 1);
    final height = switch (size) {
      WorkspaceCardSize.compact => widget.standardHeight * .72,
      WorkspaceCardSize.standard ||
      WorkspaceCardSize.wide => widget.standardHeight,
      WorkspaceCardSize.large => widget.standardHeight * 1.45,
    };
    final renderedCard = size == WorkspaceCardSize.compact
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: widget.standardHeight,
              child: card.child,
            ),
          )
        : card.child;
    final content = SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(ignoring: _editing, child: renderedCard),
          if (_editing)
            _EditOverlay(
              title: card.title,
              size: size,
              onHide: () => widget.preferences.setVisible(
                widget.pageId,
                _defaults,
                card.id,
                false,
              ),
              onResize: () => widget.preferences.setSize(
                widget.pageId,
                _defaults,
                card.id,
                size.next,
              ),
            ),
        ],
      ),
    );
    if (!_editing) return content;
    final currentIndex = allStates.indexWhere((item) => item.id == state.id);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != state.id,
      onAcceptWithDetails: (details) {
        final oldIndex = allStates.indexWhere(
          (item) => item.id == details.data,
        );
        widget.preferences.reorder(
          widget.pageId,
          _defaults,
          oldIndex,
          currentIndex,
        );
        setState(() => _draggingId = null);
      },
      // Desktop users expect a mouse drag to begin immediately. A
      // LongPressDraggable made the workspace appear inert when used with a
      // mouse or trackpad; Draggable still supports touch while giving the
      // visible drag handle normal desktop semantics.
      builder: (context, candidates, rejected) => Draggable<String>(
        data: state.id,
        onDragStarted: () => setState(() => _draggingId = state.id),
        onDragEnd: (_) => setState(() => _draggingId = null),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: .9,
            child: SizedBox(
              width: width.clamp(220, 420),
              height: 120,
              child: card.child,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: .25, child: content),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: candidates.isNotEmpty || _draggingId == state.id
                  ? AppColors.accent
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar({
    required this.pageLabel,
    required this.editing,
    required this.hidden,
    required this.cardsById,
    required this.onEditing,
    required this.onRestore,
    required this.onReset,
    required this.onLayouts,
  });
  final String pageLabel;
  final bool editing;
  final List<WorkspaceCardState> hidden;
  final Map<String, WorkspaceCard> cardsById;
  final VoidCallback onEditing, onReset, onLayouts;
  final ValueChanged<String> onRestore;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton.tonalIcon(
        onPressed: onEditing,
        icon: Icon(
          editing ? Icons.done_rounded : Icons.dashboard_customize_rounded,
        ),
        label: Text(editing ? 'Done editing' : 'Arrange cards'),
      ),
      OutlinedButton.icon(
        onPressed: onLayouts,
        icon: const Icon(Icons.bookmarks_outlined),
        label: const Text('Saved layouts'),
      ),
      if (hidden.isNotEmpty)
        PopupMenuButton<String>(
          tooltip: 'Restore hidden cards',
          onSelected: onRestore,
          itemBuilder: (_) => [
            for (final card in hidden)
              PopupMenuItem(
                value: card.id,
                child: Text('Restore ${cardsById[card.id]?.title ?? card.id}'),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.visibility_off_outlined, size: 16),
            label: Text('${hidden.length} hidden'),
          ),
        ),
      if (editing)
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text('Reset $pageLabel'),
        ),
      if (editing)
        Text(
          'Drag cards to reorder · Resize cycles compact, standard, wide and large',
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
        ),
    ],
  );
}

class _EditOverlay extends StatelessWidget {
  const _EditOverlay({
    required this.title,
    required this.size,
    required this.onHide,
    required this.onResize,
  });
  final String title;
  final WorkspaceCardSize size;
  final VoidCallback onHide, onResize;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .32),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.accent.withValues(alpha: .55)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface(context).withValues(alpha: .94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Resize card',
                onPressed: onResize,
                icon: const Icon(Icons.aspect_ratio_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Remove card',
                onPressed: onHide,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Chip(
              label: Text(size.label),
              avatar: const Icon(Icons.open_in_full_rounded, size: 14),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.onRestore});
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.overlay(context, .03),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(
      children: [
        const Icon(Icons.dashboard_customize_outlined, size: 36),
        const SizedBox(height: 10),
        const Text(
          'Every card is hidden',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore default cards'),
        ),
      ],
    ),
  );
}

Future<void> showCardLayoutsDialog({
  required BuildContext context,
  required CardWorkspacePreferences preferences,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SavedLayoutsDialog(preferences: preferences),
  );
}

class _SavedLayoutsDialog extends StatefulWidget {
  const _SavedLayoutsDialog({required this.preferences});
  final CardWorkspacePreferences preferences;
  @override
  State<_SavedLayoutsDialog> createState() => _SavedLayoutsDialogState();
}

class _SavedLayoutsDialogState extends State<_SavedLayoutsDialog> {
  final _name = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.preferences.addListener(_changed);
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_changed);
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await widget.preferences.saveLayout(_name.text);
    _name.clear();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saved card layouts'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A saved layout captures ordering, card sizes and hidden cards across every configured page.',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Layout name',
                    hintText: 'Gaming, Minimal, Diagnostics…',
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save current'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: widget.preferences.savedLayouts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No saved layouts yet.'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.preferences.savedLayouts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final layout = widget.preferences.savedLayouts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.dashboard_customize_rounded),
                        title: Text(layout.name),
                        subtitle: Text(
                          '${layout.pages.length} configured page(s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  widget.preferences.applyLayout(layout.id),
                              child: const Text('Apply'),
                            ),
                            IconButton(
                              tooltip: 'Delete layout',
                              onPressed: () =>
                                  widget.preferences.deleteLayout(layout.id),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Done'),
      ),
    ],
  );
}
