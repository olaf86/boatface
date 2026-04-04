import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final Provider<RewardedContinueAdService> rewardedContinueAdServiceProvider =
    Provider<RewardedContinueAdService>((Ref ref) {
      return const AdMobRewardedContinueAdService();
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
  Future<RewardedContinueAdResult> showContinueAd();
}

class AdMobRewardedContinueAdService implements RewardedContinueAdService {
  const AdMobRewardedContinueAdService();

  static const Duration _kAdLoadTimeout = Duration(seconds: 3);
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

  @override
  Future<RewardedContinueAdResult> showContinueAd() async {
    if (!_supportsRewardedAds) {
      return const RewardedContinueAdResult.granted(
        RewardedContinueAdOutcome.unavailableFallback,
      );
    }

    final Completer<RewardedContinueAdResult> completer =
        Completer<RewardedContinueAdResult>();
    Timer? loadTimeoutTimer;
    bool settled = false;

    void complete(RewardedContinueAdResult result) {
      if (settled) {
        return;
      }
      settled = true;
      loadTimeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    try {
      loadTimeoutTimer = Timer(_kAdLoadTimeout, () {
        complete(
          const RewardedContinueAdResult.granted(
            RewardedContinueAdOutcome.timeoutFallback,
          ),
        );
      });

      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(keywords: _kRewardedAdKeywords),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd rewardedAd) {
            if (settled) {
              rewardedAd.dispose();
              return;
            }
            loadTimeoutTimer?.cancel();
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

            try {
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
          },
          onAdFailedToLoad: (LoadAdError error) {
            complete(
              const RewardedContinueAdResult.granted(
                RewardedContinueAdOutcome.loadFailedFallback,
              ),
            );
          },
        ),
      );
    } catch (_) {
      complete(
        const RewardedContinueAdResult.granted(
          RewardedContinueAdOutcome.unavailableFallback,
        ),
      );
    }

    return completer.future;
  }

  bool get _supportsRewardedAds => Platform.isAndroid || Platform.isIOS;

  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    throw UnsupportedError(
      'Rewarded ads are only supported on iOS and Android.',
    );
  }
}
