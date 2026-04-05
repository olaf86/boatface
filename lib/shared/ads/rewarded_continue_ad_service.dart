import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../environment/app_environment.dart';
import '../privacy/ad_privacy_consent_service.dart';

final Provider<RewardedContinueAdService> rewardedContinueAdServiceProvider =
    Provider<RewardedContinueAdService>((Ref ref) {
      final service = AdMobRewardedContinueAdService(
        isProduction: ref.read(appEnvironmentProvider).isProduction,
        canRequestAds: () async {
          final AdPrivacyConsentInfo info = await ref
              .read(adPrivacyConsentServiceProvider)
              .fetchInfo();
          return info.canRequestAds;
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });

enum RewardedContinueAdOutcome {
  earnedReward,
  dismissedWithoutReward,
  unavailableFallback,
  timeoutFallback,
  loadFailedFallback,
  showFailedFallback,
}

class RewardedContinueAdResult {
  const RewardedContinueAdResult.granted(this.outcome) : granted = true;

  const RewardedContinueAdResult.denied(this.outcome) : granted = false;

  final bool granted;
  final RewardedContinueAdOutcome outcome;
}

abstract class RewardedContinueAdService {
  Future<void> preloadContinueAd();
  Future<RewardedContinueAdResult> showContinueAd();
  void dispose();
}

class AdMobRewardedContinueAdService implements RewardedContinueAdService {
  AdMobRewardedContinueAdService({
    required bool isProduction,
    required Future<bool> Function() canRequestAds,
  }) : _isProduction = isProduction,
       _canRequestAds = canRequestAds;

  static const Duration _kAdLoadTimeout = Duration(seconds: 10);
  static const String _kAndroidTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _kIosTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _kAndroidProdRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_AD_UNIT_ID_PROD',
  );
  static const String _kIosProdRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD',
  );
  static const List<String> _kRewardedAdKeywords = <String>[
    'memory game',
    'puzzle game',
    'sports game',
    'boatrace',
    'boat racing',
    'motorsports',
    '記憶ゲーム',
    'パズルゲーム',
    'スポーツゲーム',
    'ボートレース',
    'モータースポーツ',
  ];

  RewardedAd? _cachedAd;
  Completer<void>? _preloadCompleter;
  Timer? _loadTimeoutTimer;
  RewardedContinueAdOutcome? _lastPreloadFallbackOutcome;
  bool _disposed = false;
  final bool _isProduction;
  final Future<bool> Function() _canRequestAds;

  @override
  Future<void> preloadContinueAd() async {
    if (_disposed || !_supportsRewardedAds || _cachedAd != null) {
      return;
    }
    if (!await _canRequestAdsSafely()) {
      _lastPreloadFallbackOutcome =
          RewardedContinueAdOutcome.unavailableFallback;
      return;
    }
    final String adUnitId = _rewardedAdUnitId;
    final Completer<void>? inFlight = _preloadCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final Completer<void> completer = Completer<void>();
    _preloadCompleter = completer;
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_kAdLoadTimeout, () {
      _lastPreloadFallbackOutcome = RewardedContinueAdOutcome.timeoutFallback;
      _finishPreload();
    });

    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(keywords: _kRewardedAdKeywords),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd rewardedAd) {
            if (_disposed) {
              rewardedAd.dispose();
              _finishPreload();
              return;
            }
            _cachedAd?.dispose();
            _cachedAd = rewardedAd;
            _lastPreloadFallbackOutcome = null;
            _finishPreload();
          },
          onAdFailedToLoad: (LoadAdError error) {
            _lastPreloadFallbackOutcome =
                RewardedContinueAdOutcome.loadFailedFallback;
            _finishPreload();
          },
        ),
      );
    } catch (_) {
      _lastPreloadFallbackOutcome =
          RewardedContinueAdOutcome.unavailableFallback;
      _finishPreload();
    }

    return completer.future;
  }

  @override
  Future<RewardedContinueAdResult> showContinueAd() async {
    if (!_supportsRewardedAds) {
      return const RewardedContinueAdResult.granted(
        RewardedContinueAdOutcome.unavailableFallback,
      );
    }
    if (!await _canRequestAdsSafely()) {
      return const RewardedContinueAdResult.granted(
        RewardedContinueAdOutcome.unavailableFallback,
      );
    }

    await preloadContinueAd();
    final RewardedAd? rewardedAd = _cachedAd;
    if (rewardedAd == null) {
      return RewardedContinueAdResult.granted(
        _lastPreloadFallbackOutcome ??
            RewardedContinueAdOutcome.timeoutFallback,
      );
    }
    _cachedAd = null;

    final Completer<RewardedContinueAdResult> completer =
        Completer<RewardedContinueAdResult>();
    bool settled = false;

    void complete(RewardedContinueAdResult result) {
      if (settled) {
        return;
      }
      settled = true;
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      unawaited(preloadContinueAd());
    }

    try {
      bool rewardEarned = false;

      rewardedAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (Ad ad) {
          ad.dispose();
          if (rewardEarned) {
            complete(
              const RewardedContinueAdResult.granted(
                RewardedContinueAdOutcome.earnedReward,
              ),
            );
            return;
          }
          complete(
            const RewardedContinueAdResult.denied(
              RewardedContinueAdOutcome.dismissedWithoutReward,
            ),
          );
        },
        onAdFailedToShowFullScreenContent: (Ad ad, AdError error) {
          ad.dispose();
          complete(
            const RewardedContinueAdResult.granted(
              RewardedContinueAdOutcome.showFailedFallback,
            ),
          );
        },
      );

      rewardedAd.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewardEarned = true;
        },
      );
    } catch (_) {
      rewardedAd.dispose();
      complete(
        const RewardedContinueAdResult.granted(
          RewardedContinueAdOutcome.showFailedFallback,
        ),
      );
    }

    return completer.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _loadTimeoutTimer?.cancel();
    _cachedAd?.dispose();
    _cachedAd = null;
    _finishPreload();
  }

  bool get _supportsRewardedAds => Platform.isAndroid || Platform.isIOS;

  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      if (_isProduction) {
        return _requireRewardedAdUnitId(
          platformLabel: 'Android',
          value: _kAndroidProdRewardedAdUnitId,
          defineName: 'ADMOB_ANDROID_REWARDED_AD_UNIT_ID_PROD',
        );
      }
      return _kAndroidTestRewardedAdUnitId;
    }
    if (Platform.isIOS) {
      if (_isProduction) {
        return _requireRewardedAdUnitId(
          platformLabel: 'iOS',
          value: _kIosProdRewardedAdUnitId,
          defineName: 'ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD',
        );
      }
      return _kIosTestRewardedAdUnitId;
    }
    throw UnsupportedError(
      'Rewarded ads are only supported on iOS and Android.',
    );
  }

  void _finishPreload() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
    final Completer<void>? completer = _preloadCompleter;
    _preloadCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<bool> _canRequestAdsSafely() async {
    try {
      return await _canRequestAds();
    } catch (_) {
      return false;
    }
  }

  String _requireRewardedAdUnitId({
    required String platformLabel,
    required String value,
    required String defineName,
  }) {
    if (value.isNotEmpty) {
      if (value == _kAndroidTestRewardedAdUnitId ||
          value == _kIosTestRewardedAdUnitId) {
        throw StateError(
          '$platformLabel prod build must not use the Google test rewarded ad unit ID.',
        );
      }
      return value;
    }
    throw StateError(
      'Missing required $platformLabel AdMob rewarded ad unit ID. '
      'Pass --dart-define=$defineName=...',
    );
  }
}
