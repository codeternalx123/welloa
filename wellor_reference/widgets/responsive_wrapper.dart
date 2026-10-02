import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// RESPONSIVE WRAPPER: Global wrapper for making apps responsive
/// Provides safe area handling and device metrics tracking
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool safeArea;
  final Color? backgroundColor;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.safeArea = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceMetricsListener(
      builder: (context, metrics) {
        final content = ResponsiveContainer(
          backgroundColor: backgroundColor,
          padding: EdgeInsets.zero,
          child: child,
        );

        if (safeArea) {
          return SafeArea(child: content);
        }

        return content;
      },
    );
  }
}

/// ADAPTIVE LAYOUT: Automatically switches between single-column (mobile) and multi-column (tablet/desktop) layouts
class AdaptiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget? desktopLayout;

  const AdaptiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        if (isDesktop && desktopLayout != null) {
          return desktopLayout!;
        } else if (isTablet && tabletLayout != null) {
          return tabletLayout!;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}

/// RESPONSIVE SCAFFOLD: Scaffold that adapts to device size
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: ResponsiveWrapper(
        safeArea: false,
        backgroundColor: backgroundColor,
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// ADAPTIVE APPBAR: AppBar that adapts its layout based on screen size
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      mobileSize: 18.0,
      tabletSize: 20.0,
      desktopSize: 24.0,
    );

    return AppBar(
      title: Text(
        title,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// ADAPTIVE DRAWER: Navigation drawer that adapts for different screens
class AdaptiveNavigation extends StatelessWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool useDrawer;

  const AdaptiveNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.useDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isCompactView(context);

    if (isMobile && useDrawer) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Navigation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
            ...List.generate(items.length, (index) {
              final item = items[index];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                selected: index == selectedIndex,
                onTap: () => onItemSelected(index),
              );
            }),
          ],
        ),
      );
    }

    // Bottom navigation for mobile, rail for tablet/desktop
    if (isMobile) {
      return BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemSelected,
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
        ],
      );
    }

    // Navigation rail for larger screens
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
      extended: MediaQuery.of(context).size.width > 600,
    );
  }
}

/// Navigation item model
class NavigationItem {
  final IconData icon;
  final String label;
  final Widget page;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.page,
  });
}

/// RESPONSIVE DIVIDER: Divider that adapts its padding
class ResponsiveDivider extends StatelessWidget {
  final double? height;
  final Color? color;

  const ResponsiveDivider({
    super.key,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveUtils.getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding.vertical / 2),
      child: Divider(
        height: height,
        color: color,
      ),
    );
  }
}

/// RESPONSIVE CARD: Card that adapts its elevation and padding for different screens
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = ResponsiveUtils.getResponsivePadding(context);
    final isMobile = ResponsiveUtils.isCompactView(context);

    return Card(
      elevation: elevation ?? (isMobile ? 2 : 4),
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}

/// RESPONSIVE BUTTON: Button that adapts its size for different screens
class ResponsiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;

  const ResponsiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      mobileSize: 14.0,
      tabletSize: 16.0,
      desktopSize: 18.0,
    );

    final padding = ResponsiveUtils.getResponsivePadding(context);

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: padding.left,
          vertical: padding.top / 2,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(fontSize: fontSize),
                ),
              ],
            ),
    );
  }
}
