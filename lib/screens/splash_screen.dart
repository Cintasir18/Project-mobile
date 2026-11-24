import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../main.dart';

class EloraSplashPage
    extends StatefulWidget {
  const EloraSplashPage({
    super.key,
  });

  @override
  State<EloraSplashPage> createState() =>
      _EloraSplashPageState();
}

class _EloraSplashPageState
    extends State<EloraSplashPage>
    with SingleTickerProviderStateMixin {

  late AnimationController
      _controller;

  late Animation<double>
      _logoScale;

  late Animation<double>
      _logoFade;

  late Animation<double>
      _textFade;

  late Animation<double>
      _waveProgress;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds:
            2700,
      ),
    );

    // ==============================
    // LOGO
    // ==============================

    _logoScale =
        Tween<double>(
      begin:
          0.65,
      end:
          1.0,
    ).animate(
      CurvedAnimation(
        parent:
            _controller,
        curve:
            const Interval(
          0.0,
          0.35,
          curve:
              Curves.easeOutBack,
        ),
      ),
    );

    // ==============================
    // LOGO FADE
    // ==============================

    _logoFade =
        Tween<double>(
      begin:
          0,
      end:
          1,
    ).animate(
      CurvedAnimation(
        parent:
            _controller,
        curve:
            const Interval(
          0.0,
          0.25,
          curve:
              Curves.easeOut,
        ),
      ),
    );

    // ==============================
    // TEXT FADE
    // ==============================

    _textFade =
        Tween<double>(
      begin:
          0,
      end:
          1,
    ).animate(
      CurvedAnimation(
        parent:
            _controller,
        curve:
            const Interval(
          0.22,
          0.50,
          curve:
              Curves.easeOut,
        ),
      ),
    );

    // ==============================
    // CURVE TRANSITION
    // ==============================

    _waveProgress =
        Tween<double>(
      begin:
          0,
      end:
          1,
    ).animate(
      CurvedAnimation(
        parent:
            _controller,
        curve:
            const Interval(
          0.48,
          1.0,
          curve:
              Curves.easeInOutCubic,
        ),
      ),
    );

    _controller.forward();

    // ==============================
    // PINDAH KE AUTH
    // ==============================

    Future.delayed(
      const Duration(
        milliseconds:
            2850,
      ),
      () {
        if (!mounted) return;

        Navigator.of(
          context,
        ).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (
              context,
              animation,
              secondaryAnimation,
            ) {
              return const AuthCheckPage();
            },

            transitionsBuilder:
                (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity:
                    animation,
                child:
                    child,
              );
            },

            transitionDuration:
                const Duration(
              milliseconds:
                  450,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          eloraPrimary,

      body:
          AnimatedBuilder(
        animation:
            _controller,

        builder:
            (
          context,
          child,
        ) {
          return Stack(
            children: [

              // ==========================================
              // BACKGROUND TEAL
              // ==========================================

              Container(
                color:
                    eloraPrimary,
              ),

              // ==========================================
              // WHITE CURVE
              // ==========================================

              ClipPath(
                clipper:
                    EloraSplashClipper(
                  progress:
                      _waveProgress.value,
                ),
                child:
                    Container(
                  color:
                      eloraBackground,
                ),
              ),

              // ==========================================
              // BRAND
              // ==========================================

              Positioned.fill(
                child:
                    Center(
                  child:
                      Opacity(
                    opacity:
                        _logoFade.value *
                        (
                          1 -
                              (
                                _waveProgress.value *
                                    0.85
                              )
                        ),

                    child:
                        Transform.scale(
                      scale:
                          _logoScale.value,

                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          // ICON
                          Container(
                            width:
                                88,
                            height:
                                88,

                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white.withValues(
                                alpha:
                                    0.13,
                              ),

                              borderRadius:
                                  BorderRadius.circular(
                                27,
                              ),

                              border:
                                  Border.all(
                                color:
                                    Colors.white.withValues(
                                  alpha:
                                      0.16,
                                ),
                                width:
                                    1,
                              ),
                            ),

                            child:
                                const Icon(
                              Icons
                                  .school_rounded,
                              color:
                                  Colors.white,
                              size:
                                  44,
                            ),
                          ),

                          const SizedBox(
                            height:
                                22,
                          ),

                          // ELORA
                          const Text(
                            'ELORA',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  28,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing:
                                  5,
                            ),
                          ),

                          const SizedBox(
                            height:
                                8,
                          ),

                          // SUBTITLE
                          Opacity(
                            opacity:
                                _textFade.value,

                            child:
                                const Text(
                              'Your student companion',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white70,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight.w500,
                                letterSpacing:
                                    0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ==========================================
              // LOADING
              // ==========================================

              Positioned(
                left:
                    0,
                right:
                    0,
                bottom:
                    42,

                child:
                    Opacity(
                  opacity:
                      _textFade.value,

                  child:
                      const Center(
                    child:
                        SizedBox(
                      width:
                          19,
                      height:
                          19,

                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            1.8,
                        color:
                            Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================
// CURVED SPLASH
// ==========================================================

class EloraSplashClipper
    extends CustomClipper<Path> {

  final double progress;

  const EloraSplashClipper({
    required this.progress,
  });

  @override
  Path getClip(
    Size size,
  ) {
    final path =
        Path();

    final startY =
        size.height *
        (
          1.08 -
              (
                progress *
                    0.76
              )
        );

    path.moveTo(
      0,
      startY,
    );

    path.cubicTo(
      size.width *
          0.20,
      startY -
          55,

      size.width *
          0.45,
      startY +
          55,

      size.width *
          0.68,
      startY -
          20,
    );

    path.cubicTo(
      size.width *
          0.83,
      startY -
          65,

      size.width *
          0.94,
      startY -
          25,

      size.width,
      startY -
          45,
    );

    path.lineTo(
      size.width,
      size.height,
    );

    path.lineTo(
      0,
      size.height,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant EloraSplashClipper
        oldClipper) {
    return oldClipper.progress !=
        progress;
  }
}