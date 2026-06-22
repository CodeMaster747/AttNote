import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// A navigation destination shown in the collapsible sidebar.
class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;
}

/// Responsive app shell with a collapsible sidebar.
///
/// Wide layouts (>= 900px) show a persistent rail that collapses to icons;
/// narrow layouts move the same navigation into a [Drawer] behind a menu
/// button. The [body] is the page's primary (dashboard) content and should be
/// scrollable on its own.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.userName,
    required this.items,
    required this.body,
    required this.onLogout,
    this.subtitle,
    this.headerActions = const [],
  });

  final String title;
  final String userName;
  final String? subtitle;
  final List<SidebarItem> items;
  final Widget body;
  final VoidCallback onLogout;
  final List<Widget> headerActions;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (wide) {
          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Row(
                children: [
                  _Sidebar(
                    extended: !_collapsed,
                    title: widget.title,
                    userName: widget.userName,
                    subtitle: widget.subtitle,
                    items: widget.items,
                    onToggle: () => setState(() => _collapsed = !_collapsed),
                    onLogout: widget.onLogout,
                  ),
                  Container(width: 1, color: colors.border),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Row(
              children: [
                const AppLogo(size: 28),
                const Gap(AppSpacing.xs),
                Text(widget.title),
              ],
            ),
            actions: widget.headerActions,
          ),
          drawer: Drawer(
            backgroundColor: colors.surface,
            child: _Sidebar(
              extended: true,
              title: widget.title,
              userName: widget.userName,
              subtitle: widget.subtitle,
              items: widget.items,
              onLogout: widget.onLogout,
              insideDrawer: true,
            ),
          ),
          body: widget.body,
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.extended,
    required this.title,
    required this.userName,
    required this.subtitle,
    required this.items,
    required this.onLogout,
    this.onToggle,
    this.insideDrawer = false,
  });

  final bool extended;
  final String title;
  final String userName;
  final String? subtitle;
  final List<SidebarItem> items;
  final VoidCallback onLogout;
  final VoidCallback? onToggle;
  final bool insideDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final width = extended ? 260.0 : 76.0;

    return AnimatedContainer(
      duration: AppDuration.base,
      curve: Curves.easeOut,
      width: width,
      color: colors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                const AppLogo(size: 30),
                if (extended) ...[
                  const Gap(AppSpacing.xs),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        )),
                  ),
                  if (onToggle != null)
                    IconButton(
                      icon: const Icon(Icons.menu_open, size: 18),
                      tooltip: 'Collapse',
                      onPressed: onToggle,
                    ),
                ],
              ],
            ),
          ),
          if (!extended && onToggle != null) ...[
            const Gap(AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.menu, size: 18),
              tooltip: 'Expand',
              onPressed: onToggle,
            ),
          ],
          const Gap(AppSpacing.lg),

          // Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in items)
                  _SidebarTile(
                    item: item,
                    extended: extended,
                    onTap: () {
                      if (insideDrawer) Navigator.pop(context);
                      item.onTap();
                    },
                  ),
              ],
            ),
          ),

          // Footer
          if (extended && userName.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.surfaceMuted,
                    child: Text(
                      userName[0].toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.textPrimary,
                            )),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.xs),
          ],
          _SidebarTile(
            item: SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Log out',
              onTap: () {
                if (insideDrawer) Navigator.pop(context);
                onLogout();
              },
            ),
            extended: extended,
            onTap: () {
              if (insideDrawer) Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.item,
    required this.extended,
    required this.onTap,
  });

  final SidebarItem item;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final selected = widget.item.selected;
    final bg = selected
        ? colors.surfaceMuted
        : _hovered
            ? colors.surfaceMuted
            : Colors.transparent;
    final fg = selected ? colors.textPrimary : colors.textSecondary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            widget.extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(widget.item.icon, size: 18, color: fg),
          if (widget.extended) ...[
            const Gap(AppSpacing.sm),
            Expanded(
              child: Text(widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ),
            if (widget.item.trailing != null) widget.item.trailing!,
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: widget.extended
                ? content
                : Tooltip(message: widget.item.label, child: content),
          ),
        ),
      ),
    );
  }
}
