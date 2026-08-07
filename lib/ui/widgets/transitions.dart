import 'package:flutter/material.dart';

/// A gentle fade-through page transition used across the app instead of the
/// default platform slide. The new screen fades in while easing up from a
/// subtle scale, which reads calmer than an abrupt push — fitting a relaxing
/// pixel-art experience.
/// [name] labels the route for Firebase's automatic screen_view tracking
/// (and debugging); it has no effect on navigation itself.
/// Theme-level twin of [fadeThroughRoute] so default routes ([MaterialPageRoute],
/// dialogs' internal pushes, and every `Navigator.pop`) use the same calm
/// fade-through instead of the stock Material zoom/slide.
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

Route<T> fadeThroughRoute<T>(Widget page, {String? name}) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(
        opacity: curved,
        // Settle from 98% -> 100% for a soft "ease in" without motion that
        // could feel jarring.
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
