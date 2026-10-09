import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown if /victory or /defeat is opened with no battle result (deep link,
/// hot restart): sends the user home instead of showing invented numbers.
class NoResultRedirect extends StatefulWidget {
  const NoResultRedirect({super.key});

  @override
  State<NoResultRedirect> createState() => _NoResultRedirectState();
}

class _NoResultRedirectState extends State<NoResultRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
