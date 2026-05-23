import 'package:flutter/material.dart';

import '../widgets/glass_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050505), Color(0xFF090909), Color(0xFF04070D)],
          ),
        ),

        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -120,

              child: Container(
                width: 400,
                height: 400,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  gradient: RadialGradient(
                    colors: [Colors.cyan.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),

            Center(
              child: SizedBox(
                width: 420,

                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: const [
                      Text(
                        'CPU Usage',

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),

                      SizedBox(height: 16),

                      Text(
                        '24%',

                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
