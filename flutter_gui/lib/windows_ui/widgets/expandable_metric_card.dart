import 'package:flutter/material.dart';

class ExpandableMetricCard extends StatelessWidget {
  final Widget closedChild;
  final String title;

  const ExpandableMetricCard({
    super.key,
    required this.closedChild,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(24),

        onTap: () {
          Navigator.push(
            context,

            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),

              pageBuilder: (_, __, ___) {
                return Scaffold(
                  backgroundColor: const Color(0xFF050505),

                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(32),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),

                            icon: const Icon(Icons.close, color: Colors.white),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            title,

                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Expanded analytics view coming next...',

                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },

              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },

        child: closedChild,
      ),
    );
  }
}
