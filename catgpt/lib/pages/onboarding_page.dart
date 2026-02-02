import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../constants/purchase_constants.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  
  // In-app purchase
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  ProductDetails? _premiumProduct;
  bool _isLoadingProduct = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _initPremiumProduct();
  }

  Future<void> _initPremiumProduct() async {
    setState(() => _isLoadingProduct = true);
    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        setState(() => _isLoadingProduct = false);
        return;
      }
      final response = await _inAppPurchase.queryProductDetails({premiumProductId});
      if (response.productDetails.isNotEmpty) {
        _premiumProduct = response.productDetails.first;
      }
    } catch (e) {
      debugPrint('Error loading premium product: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProduct = false);
      }
    }
  }

  Future<void> _purchasePremium() async {
    if (_premiumProduct == null || _isPurchasing) return;
    
    setState(() => _isPurchasing = true);
    try {
      final purchaseParam = PurchaseParam(productDetails: _premiumProduct!);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      // Purchase stream handler in home_page will handle completion
    } catch (e) {
      debugPrint('Error purchasing premium: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFAFBFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header with skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Empty container for balance
                  const SizedBox(width: 60),
                  // Page indicator
                  Row(
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Skip button
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),

            // PageView with cards
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _OnboardingVideoCard(
                    videoPath: 'assets/onboarding/screenshot_camera.mp4',
                    title: 'Snap Your Cat',
                    description: 'Use your camera or upload a photo. Our AI instantly analyzes your cat\'s expression, pose, and that signature judgmental stare.',
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.2),
                        theme.colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  _OnboardingVideoCard(
                    videoPath: 'assets/onboarding/screenshot_translation.mp4',
                    title: 'Get Instant Translations',
                    description: 'See what your cat is really thinking in seconds! From "I demand treats NOW" to "Why are you still here?" - no meow left untranslated.',
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.2),
                        theme.colorScheme.tertiary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  _OnboardingVideoCard(
                    videoPath: 'assets/onboarding/screenshot_history.mp4',
                    title: 'Save & Share',
                    description: 'Keep a history of your cat\'s greatest roasts and share them with friends. Perfect for making your cat Instagram-famous!',
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.tertiary.withOpacity(0.2),
                        theme.colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  _buildPremiumCard(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    onPurchase: _purchasePremium,
                    isPurchasing: _isPurchasing,
                    isLoadingProduct: _isLoadingProduct,
                    productPrice: _premiumProduct?.price,
                  ),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(24),
              child: _currentPage < _totalPages - 1
                  ? _buildGradientButton(
                      context: context,
                      theme: theme,
                      label: 'Next',
                      onPressed: _nextPage,
                      icon: Icons.arrow_forward_rounded,
                    )
                  : _buildGradientButton(
                      context: context,
                      theme: theme,
                      label: 'Get Started',
                      onPressed: _completeOnboarding,
                      icon: Icons.pets_rounded,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onPurchase,
    required bool isPurchasing,
    required bool isLoadingProduct,
    String? productPrice,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium image with special styling (made smaller)
          Container(
            height: screenHeight * 0.25, // Reduced from 0.35 to fit without scrolling
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24), // Reduced from 32
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/onboarding/screenshot_premium.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 100,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Premium badge overlay
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Premium title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'CatGPT Premium',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // Reduced from 20

          // Premium features
          Container(
            padding: const EdgeInsets.all(16), // Reduced from 18
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  theme: theme,
                  icon: Icons.history_rounded,
                  text: 'Unlimited translation history',
                ),
                const SizedBox(height: 8), // Reduced from 10
                _buildFeatureRow(
                  theme: theme,
                  icon: Icons.no_photography_rounded,
                  text: 'No watermarks on shares',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  theme: theme,
                  icon: Icons.block_rounded,
                  text: 'Ad-free experience',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  theme: theme,
                  icon: Icons.favorite_rounded,
                  text: 'Support indie developers!',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // Reduced from 20

          // Purchase button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isPurchasing || isLoadingProduct ? null : onPurchase,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPurchasing || isLoadingProduct)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else ...[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isLoadingProduct
                              ? 'Loading...'
                              : 'Get Premium - ${productPrice ?? premiumFallbackPrice}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16

          // Restore purchases button
          TextButton(
            onPressed: isPurchasing || isLoadingProduct ? null : () async {
              setState(() => _isPurchasing = true);
              try {
                await _inAppPurchase.restorePurchases();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchases restored!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: ${e.toString()}')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isPurchasing = false);
                }
              }
            },
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Price hint
          Text(
            'One-time purchase • No subscription',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required ThemeData theme,
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Separate widget for video cards that manages its own video controller
class _OnboardingVideoCard extends StatefulWidget {
  final String videoPath;
  final String title;
  final String description;
  final Gradient gradient;

  const _OnboardingVideoCard({
    required this.videoPath,
    required this.title,
    required this.description,
    required this.gradient,
  });

  @override
  State<_OnboardingVideoCard> createState() => _OnboardingVideoCardState();
}

class _OnboardingVideoCardState extends State<_OnboardingVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0); // Muted like a GIF
      await _controller!.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video container optimized for phone-sized videos (no border)
          Container(
            height: screenHeight * 0.5,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _isInitialized && _controller != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: _hasError
                            ? Icon(
                                Icons.pets_rounded,
                                size: 80,
                                color: theme.colorScheme.primary.withOpacity(0.3),
                              )
                            : CircularProgressIndicator(
                                color: theme.colorScheme.primary.withOpacity(0.5),
                              ),
                      ),
                    ),
            ),
          ),

          // Title
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
