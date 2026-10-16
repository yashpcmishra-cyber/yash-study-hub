import 'package:flutter/material.dart';
import '../../widgets/depth_card.dart';
import '../../app_colors.dart';

/// Admin-only list that can be arranged by hand: press and drag the handle on
/// the left, or tap the small up / down arrows on the right.
///
/// The widget keeps its own copy of the list so the row jumps to the new place
/// immediately, then calls [onSave] with the full new order. If saving fails the
/// list goes back to what Firestore has and a message is shown.
///
/// It is built with `shrinkWrap`, so it can sit inside the admin tabs' normal
/// ListView / Column without needing a fixed height.
class AdminReorderList<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) idOf;

  /// The row content (usually the same ListTile that was used before).
  final Widget Function(BuildContext context, T item) contentBuilder;

  /// Called with the whole list in its new order.
  final Future<void> Function(List<T> newOrder) onSave;

  /// true = every row sits in a DepthCard (like the Batches / Banners lists).
  final bool inCard;

  const AdminReorderList({
    super.key,
    required this.items,
    required this.idOf,
    required this.contentBuilder,
    required this.onSave,
    this.inCard = false,
  });

  @override
  State<AdminReorderList<T>> createState() => _AdminReorderListState<T>();
}

class _AdminReorderListState<T> extends State<AdminReorderList<T>> {
  late List<T> _local = List<T>.of(widget.items);

  // How many order-saves are still running. While > 0 the list keeps showing
  // the admin's own order instead of older data that may still arrive from
  // the stream.
  int _saving = 0;

  bool _sameOrder(List<T> other) {
    if (other.length != _local.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (widget.idOf(other[i]) != widget.idOf(_local[i])) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant AdminReorderList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_saving > 0) {
      // Firestore has caught up with our order: go back to following it.
      if (_sameOrder(widget.items)) _saving = 0;
      if (_saving > 0) return;
    }
    _local = List<T>.of(widget.items);
  }

  Future<void> _applyOrder(List<T> next) async {
    setState(() {
      _local = next;
      _saving++;
    });
    try {
      await widget.onSave(List<T>.of(next));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = 0;
        _local = List<T>.of(widget.items);
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Could not save the new order: $e')));
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_saving > 0) _saving--;
      if (_saving == 0) _local = List<T>.of(widget.items);
    });
  }

  void _move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _local.length || to >= _local.length) return;
    final next = List<T>.of(_local);
    next.insert(to, next.removeAt(from));
    _applyOrder(next);
  }

  Widget _arrow(IconData icon, String tip, VoidCallback? onTap) {
    return SizedBox(
      width: 30,
      height: 22,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        iconSize: 20,
        splashRadius: 14,
        constraints: const BoxConstraints.tightFor(width: 30, height: 22),
        icon: Icon(icon, color: onTap == null ? AppC.text24 : AppC.text70),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _local.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        _move(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) => Material(
        color: AppC.panel,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (context, i) {
        final item = _local[i];
        final row = Row(
          children: [
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 12, 4, 12),
                child: Icon(Icons.drag_indicator, color: AppC.muted, size: 22),
              ),
            ),
            SizedBox(
              width: 18,
              child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 11)),
            ),
            Expanded(child: widget.contentBuilder(context, item)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrow(Icons.keyboard_arrow_up, 'Move up', i == 0 ? null : () => _move(i, i - 1)),
                _arrow(Icons.keyboard_arrow_down, 'Move down', i == _local.length - 1 ? null : () => _move(i, i + 1)),
              ],
            ),
            const SizedBox(width: 4),
          ],
        );
        return KeyedSubtree(
          key: ValueKey(widget.idOf(item)),
          child: widget.inCard ? DepthCard(margin: const EdgeInsets.only(bottom: 8), child: row) : row,
        );
      },
    );
  }
}

/// A collapsed "Change folder order" box for the admin tabs, where folders are
/// otherwise picked from a dropdown. Opens a small [AdminReorderList] of the
/// folder names. Hidden by the caller when there are fewer than 2 folders.
class AdminFolderOrderSection<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final Future<void> Function(List<T> newOrder) onSave;

  const AdminFolderOrderSection({
    super.key,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: AppC.accent,
        collapsedIconColor: AppC.muted,
        leading: Icon(Icons.swap_vert, color: AppC.accent, size: 20),
        title: Text('Change folder order', style: TextStyle(color: AppC.text, fontSize: 13)),
        subtitle: Text('Drag the handle or tap the arrows. Students see the same order.', style: TextStyle(color: AppC.muted, fontSize: 11)),
        children: [
          AdminReorderList<T>(
            items: items,
            idOf: idOf,
            onSave: onSave,
            contentBuilder: (context, f) => ListTile(
              dense: true,
              title: Text(labelOf(f), style: TextStyle(color: AppC.text, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
