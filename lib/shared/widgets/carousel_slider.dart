import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';
import '../themes/app_animations.dart';
import '../themes/app_icon_sizes.dart';

/// Custom carousel/slider widget for displaying multiple items
/// Supports auto-scroll, manual navigation, and page indicators
class CarouselSlider extends StatefulWidget {
  final List<Widget> items;
  final Duration autoScrollDuration;
  final bool enableAutoScroll;
  final bool enableIndicators;
  final bool enableNavigation;
  final double height;
  final double indicatorHeight;
  final EdgeInsets padding;
  final void Function(int)? onPageChanged;
  final Curve scrollCurve;

  const CarouselSlider({
    super.key,
    required this.items,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.enableAutoScroll = false,
    this.enableIndicators = true,
    this.enableNavigation = true,
    this.height = 200,
    this.indicatorHeight = 40,
    this.padding = const EdgeInsets.all(0),
    this.onPageChanged,
    this.scrollCurve = Curves.easeInOut,
  });

  @override
  State<CarouselSlider> createState() => _CarouselSliderState();
}

class _CarouselSliderState extends State<CarouselSlider>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    if (widget.enableAutoScroll) {
      _animationController = AnimationController(
        duration: widget.autoScrollDuration,
        vsync: this,
      );
      _startAutoScroll();
    } else {
      _animationController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      );
    }
  }

  void _startAutoScroll() {
    _animationController.forward().then((_) {
      if (mounted) {
        if (_currentPage < widget.items.length - 1) {
          _pageController.nextPage(
            duration: AppAnimations.pageTransitionConfig.duration,
            curve: widget.scrollCurve,
          );
        } else {
          _pageController.animateToPage(
            0,
            duration: AppAnimations.pageTransitionConfig.duration,
            curve: widget.scrollCurve,
          );
        }
        _animationController.reset();
        _startAutoScroll();
      }
    });
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: AppAnimations.pageTransitionConfig.duration,
      curve: widget.scrollCurve,
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: AppAnimations.pageTransitionConfig.duration,
      curve: widget.scrollCurve,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Carousel content
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              /// Page view
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  widget.onPageChanged?.call(index);
                  if (widget.enableAutoScroll) {
                    _animationController.reset();
                    _startAutoScroll();
                  }
                },
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = index - _pageController.page!;
                        value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                      }
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: widget.padding,
                      child: widget.items[index],
                    ),
                  );
                },
              ),

              /// Left navigation button
              if (widget.enableNavigation)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavigationButton(
                      icon: Icons.chevron_left,
                      onPressed: _previousPage,
                    ),
                  ),
                ),

              /// Right navigation button
              if (widget.enableNavigation)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavigationButton(
                      icon: Icons.chevron_right,
                      onPressed: _nextPage,
                    ),
                  ),
                ),
            ],
          ),
        ),

        /// Page indicators
        if (widget.enableIndicators)
          Padding(
            padding: EdgeInsets.all(AppSpacing.spacing12),
            child: _PageIndicators(
              itemCount: widget.items.length,
              currentPage: _currentPage,
              height: widget.indicatorHeight,
            ),
          ),
      ],
    );
  }
}

/// Navigation button for carousel
class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textPrimary),
        onPressed: onPressed,
      ),
    );
  }
}

/// Page indicator dots
class _PageIndicators extends StatelessWidget {
  final int itemCount;
  final int currentPage;
  final double height;

  const _PageIndicators({
    required this.itemCount,
    required this.currentPage,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            itemCount,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(
                horizontal: AppSpacing.spacing4,
              ),
              width: currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? AppColors.primary
                    : AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image carousel - convenience wrapper for image carousels
class ImageCarousel extends StatelessWidget {
  final List<String> imageUrls;
  final double height;
  final BoxFit imageFit;
  final bool enableAutoScroll;
  final void Function(int)? onPageChanged;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 200,
    this.imageFit = BoxFit.cover,
    this.enableAutoScroll = false,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      items: imageUrls
          .map(
            (url) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: imageFit,
                placeholder: (context, url) => Container(
                  color: AppColors.surface,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    color: AppColors.surface,
                    child: Icon(
                      Icons.image_not_supported,
                      color: AppColors.textMuted,
                      size: AppIconSizes.display,
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
      height: height,
      enableAutoScroll: enableAutoScroll,
      enableIndicators: true,
      enableNavigation: true,
      onPageChanged: onPageChanged,
    );
  }
}

/// Custom carousel for widgets
class WidgetCarousel extends StatelessWidget {
  final List<Widget> widgets;
  final double height;
  final bool enableAutoScroll;
  final Duration autoScrollDuration;
  final void Function(int)? onPageChanged;

  const WidgetCarousel({
    super.key,
    required this.widgets,
    this.height = 200,
    this.enableAutoScroll = false,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      items: widgets,
      height: height,
      enableAutoScroll: enableAutoScroll,
      autoScrollDuration: autoScrollDuration,
      enableIndicators: true,
      enableNavigation: true,
      onPageChanged: onPageChanged,
    );
  }
}
