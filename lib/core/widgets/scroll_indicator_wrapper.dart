import 'package:flutter/material.dart';

class ScrollIndicatorWrapper extends StatefulWidget {
  /// The scrollable widget that this indicator is for.
  /// This child MUST have its `controller` property assigned to the `scrollController`
  /// provided by the `builder`.
  final Widget Function(BuildContext context, ScrollController scrollController)
      builder;

  const ScrollIndicatorWrapper({super.key, required this.builder});

  @override
  State<ScrollIndicatorWrapper> createState() => _ScrollIndicatorWrapperState();
}

class _ScrollIndicatorWrapperState extends State<ScrollIndicatorWrapper>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _showScrollIndicator = false;
  late final AnimationController _bounceAnimationController;
  late final Animation<Offset> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.15),
    ).animate(CurvedAnimation(
      parent: _bounceAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_scrollListener);

    // Check scroll extent after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A small delay can help ensure layout is fully complete.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _scrollListener();
        }
      });
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    bool shouldShow = position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent;

    if (shouldShow != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _bounceAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.builder(context, _scrollController),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _showScrollIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              child: Center(
                child: SlideTransition(
                  position: _bounceAnimation,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 36, color: Colors.black38),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
