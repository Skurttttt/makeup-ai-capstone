import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../home_screen.dart';

class InstructionCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String instruction;
  final VoidCallback? onTap;

  const InstructionCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.instruction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFD8E8),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STEP $stepNumber • ${title.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF3D93),
                letterSpacing: 0.1,
                height: 1,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              instruction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.2,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Color(0xFF55555C),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Tap to read full guide',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF3D93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuideCardShell extends StatelessWidget {
  final Widget child;

  const GuideCardShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: child,
    );
  }
}

class GuideImagePulseOverlay extends StatelessWidget {
  final Widget child;

  const GuideImagePulseOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: 0.18,
              duration: const Duration(milliseconds: 900),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFF3D93).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FloatingMiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const FloatingMiniButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF3D93),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: const Color(0xFFFF3D93).withOpacity(0.20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}

class KitQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDisabled;

  const KitQtyButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFF0F0F0) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDisabled ? const Color(0xFFE0E0E0) : const Color(0xFFFFD3E5),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDisabled ? Colors.grey : const Color(0xFFFF3D93),
        ),
      ),
    );
  }
}

class AiTutorialLoadingView extends StatelessWidget {
  final String lookName;

  const AiTutorialLoadingView({
    super.key,
    required this.lookName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFF4D97).withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_retouching_natural_outlined),
            selectedIcon: Icon(Icons.face_retouching_natural),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Premium',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: 90,
                    left: -80,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF4D97).withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: -70,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withOpacity(0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 145,
                    right: -8,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          'assets/images/makeup_brush.png',
                          width: 92,
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .moveY(
                              begin: -4,
                              end: 6,
                              duration: 2400.ms,
                              curve: Curves.easeInOut,
                            )
                            .then()
                            .moveY(
                              begin: 6,
                              end: -4,
                              duration: 2400.ms,
                              curve: Curves.easeInOut,
                            ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        const Text(
                          'Creating your',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF171725),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'personalized tutorial',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF4D97),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyzing your skin tone, undertone, selected look, and product matches to create your $lookName guide.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF74747A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4D97)
                                        .withOpacity(0.26),
                                    blurRadius: 42,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            ClipOval(
                              child: Image.asset(
                                'assets/images/ai_orb.png',
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .scale(
                                  duration: 2200.ms,
                                  begin: const Offset(0.94, 0.94),
                                  end: const Offset(1.04, 1.04),
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .scale(
                                  duration: 2200.ms,
                                  begin: const Offset(1.04, 1.04),
                                  end: const Offset(0.94, 0.94),
                                  curve: Curves.easeInOut,
                                ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE7D7FF),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6)
                                    .withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Shimmer.fromColors(
                            baseColor: const Color(0xFF6D4FE8),
                            highlightColor: const Color(0xFFFF4D97),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Analyzing your features...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const AiProgressCard(),
                        const SizedBox(height: 14),
                        AiInfoCard(lookName: lookName),
                        const Spacer(),
                        const AiTipCard(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AiProgressCard extends StatelessWidget {
  const AiProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD9E9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: ProgressStep(
              icon: Icons.palette_rounded,
              title: 'Selecting',
              subtitle: 'Look',
              active: false,
              done: true,
            ),
          ),
          Expanded(
            child: ProgressStep(
              icon: Icons.face_retouching_natural_rounded,
              title: 'Analyzing',
              subtitle: 'Face',
              active: false,
              done: true,
            ),
          ),
          Expanded(
            child: ProgressStep(
              icon: Icons.auto_awesome_rounded,
              title: 'Generating',
              subtitle: 'Steps',
              active: true,
              done: false,
            ),
          ),
          Expanded(
            child: ProgressStep(
              icon: Icons.description_rounded,
              title: 'Finalizing',
              subtitle: 'Guide',
              active: false,
              done: false,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool done;

  const ProgressStep({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF8B5CF6)
        : done
            ? const Color(0xFFFF4D97)
            : const Color(0xFFB8B8BF);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFF4EEFF)
                    : done
                        ? const Color(0xFFFFEEF6)
                        : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.25),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            if (done)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D97),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF74747A),
          ),
        ),
      ],
    );
  }
}

class AiInfoCard extends StatelessWidget {
  final String lookName;

  const AiInfoCard({
    super.key,
    required this.lookName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFF4D97),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "What's happening?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF171725),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Analyzing your skin tone, undertone, selected look, and product matches to create your $lookName guide.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF74747A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: 0.65,
            child: Image.asset(
              'assets/images/face_mesh.png',
              width: 78,
            ),
          ),
        ],
      ),
    );
  }
}

class AiTipCard extends StatelessWidget {
  const AiTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD9E9)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFFF4D97),
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'This may take a few moments.\n',
                    style: TextStyle(
                      color: Color(0xFFFF4D97),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: "We're crafting something beautiful ✨",
                    style: TextStyle(
                      color: Color(0xFF74747A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}