import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackHandler extends StatelessWidget {
  final Widget child;
  final String backRoute;

  const BackHandler({
    super.key,
    required this.child,
    required this.backRoute,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(backRoute);
        }
      },
      child: child,
    );
  }
}
