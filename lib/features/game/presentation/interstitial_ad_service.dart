import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract interface class InterstitialAdService {
  static final instance = GoogleInterstitialAdService();

  Future<void> initialize();

  void showInterstitial(VoidCallback onComplete);
}

final interstitialAdServiceProvider = Provider<InterstitialAdService>(
  (ref) => InterstitialAdService.instance,
);

class GoogleInterstitialAdService implements InterstitialAdService {
  static const _testAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const _releaseAdUnitId = 'ca-app-pub-2698119679435877/3138577800';

  InterstitialAd? _ad;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isShowing = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  String get _adUnitId => kReleaseMode ? _releaseAdUnitId : _testAdUnitId;

  @override
  Future<void> initialize() async {
    if (!_isAndroid || _isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _loadAd();
    } catch (error, stackTrace) {
      debugPrint('Google Mobile Ads initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void showInterstitial(VoidCallback onComplete) {
    if (_isShowing) return;

    final ad = _ad;
    if (ad == null) {
      _loadAd();
      onComplete();
      return;
    }

    _ad = null;
    _isShowing = true;
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      _isShowing = false;
      ad.dispose();
      onComplete();
      _loadAd();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial ad failed to show: $error');
        finish();
      },
    );

    unawaited(
      ad.show().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Interstitial ad show request failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        finish();
      }),
    );
  }

  void _loadAd() {
    if (!_isAndroid || !_isInitialized || _isLoading || _ad != null) return;

    _isLoading = true;
    unawaited(
      InterstitialAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoading = false;
            _ad = ad;
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            debugPrint('Interstitial ad failed to load: $error');
          },
        ),
      ).catchError((Object error, StackTrace stackTrace) {
        _isLoading = false;
        debugPrint('Interstitial ad load request failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }
}
