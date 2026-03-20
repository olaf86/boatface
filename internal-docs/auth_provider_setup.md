# Boatface Auth Provider Setup

最終更新: 2026-03-20

## 1. 目的

Boatface で使う認証方式ごとの設定手順をまとめる。

対象:
- 匿名ログイン
- Google
- Game Center
- Play Games

前提:
- Firebase Authentication をユーザー ID の source of truth にする
- Flutter アプリは `stg` / `prod` の 2 環境を持つ
- iOS は flavor ごとに別 bundle ID を使う
- Android は flavor ごとに別 applicationId を使う

## 2. Boatface の環境対応

| Environment | Firebase project | Android package | iOS bundle ID |
| --- | --- | --- | --- |
| `stg` | `boatface-stg` | `dev.asobo.boatface.stg` | `dev.asobo.boatface.stg` |
| `prod` | `boatface-prod` | `dev.asobo.boatface` | `dev.asobo.boatface` |

Firebase 設定ファイルの生成は README の手順どおりに行う。

```bash
flutter pub get
PATH="$PATH:$HOME/.pub-cache/bin" ./scripts/configure_firebase.sh stg
PATH="$PATH:$HOME/.pub-cache/bin" ./scripts/configure_firebase.sh prod
```

生成されるファイル:
- `lib/firebase_options_stg.dart`
- `lib/firebase_options_prod.dart`
- `android/app/src/stg/google-services.json`
- `android/app/src/prod/google-services.json`
- `ios/Firebase/stg/GoogleService-Info.plist`
- `ios/Firebase/prod/GoogleService-Info.plist`

注意:
- `firebase.json` の `flutter` セクションは iOS build script が参照するため、巻き戻さない
- Firebase Console 側で provider 設定を変えたあとも、必要に応じて config を再生成する

## 3. 共通の事前確認

各 provider の設定前に確認すること:

1. Firebase project と app registration が `stg` / `prod` で分かれていること
2. `Authentication > Sign-in method` を操作できる権限があること
3. iOS / Android の bundle ID, package 名が Firebase 側と一致していること
4. `flutter analyze` が通る状態であること

## 4. 匿名ログイン

### Firebase Console

`Authentication > Sign-in method` で `Anonymous` を有効化する。

### アプリ側

匿名ログインはすでに実装済み。

関連ファイル:
- `lib/features/auth/application/auth_controller.dart`
- `lib/features/auth/presentation/login_screen.dart`

補足:
- 匿名ユーザーを Google などへ昇格する場合は `linkWithCredential()` を使う
- Firebase の匿名認証は短時間に同一 IP から大量作成すると制限に当たる場合がある

## 5. Google ログイン

### 5.1 Firebase Console

`Authentication > Sign-in method` で `Google` を有効化する。

確認項目:
- support email を設定する
- `stg` / `prod` それぞれで有効化する

### 5.2 Android

Firebase に Android app が登録済みであれば、基本的には `google-services.json` の再生成で足りる。

確認項目:
- `android/app/src/stg/google-services.json`
- `android/app/src/prod/google-services.json`

追加で確認すること:
- Google Play Console / Google Cloud 側で必要な SHA-1, SHA-256 を Firebase project に登録する
- `google-services.json` に web OAuth client が含まれていること

### 5.3 iOS

Google Sign-In を有効化した後、新しい `GoogleService-Info.plist` を取得する。
Boatface ではこのファイルは `ios/Firebase/<env>/GoogleService-Info.plist` に配置する。

`google_sign_in_ios` の要件として、`ios/Runner/Info.plist` に以下を追加する。

1. `GIDClientID`
2. `CFBundleURLTypes`

値の取り方:
- `GIDClientID`: `GoogleService-Info.plist` の `CLIENT_ID`
- URL scheme: `GoogleService-Info.plist` の `REVERSED_CLIENT_ID`

この 2 つは provider 有効化後に取得した最新の `GoogleService-Info.plist` から埋める。

### 5.4 macOS

将来 macOS を有効にする場合は、`google_sign_in_ios` の要件として keychain sharing が必要。

対象ファイル:
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

追加する entitlement:

```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
</array>
```

### 5.5 Boatface の実装状況

Google ログインの Flutter 実装は追加済み。

関連ファイル:
- `lib/features/auth/application/auth_controller.dart`
- `lib/features/auth/presentation/login_screen.dart`

現在の挙動:
- 匿名ユーザーが Google でログインすると `linkWithCredential()` で昇格する
- 非匿名状態なら `signInWithCredential()` を使う

## 6. Game Center

Game Center は Apple platform 専用。

### 6.1 Firebase Console

`Authentication > Sign-in method` で `Game Center` を有効化する。

### 6.2 Apple Developer / Xcode

必要な前提:
- 対象 App ID に `Game Center` capability を付与する
- Xcode の `Signing & Capabilities` で `Game Center` を有効化する
- provisioning profile を更新する

注意:
- Apple Developer によると、Xcode 14 以降でも entitlement が自動で入らないケースがある
- capability を付けたのに entitlement が入らない場合は、Game Center capability を付け直す

確認対象:
- `ios/Runner.xcodeproj`
- entitlements file

### 6.3 実装時の前提

Firebase の Game Center 認証は、先に local player が Game Center にサインイン済みであることを前提にする。

実装時に必要なこと:
- `GKLocalPlayer.local.authenticateHandler` を使って local player を認証する
- 認証済み local player から Firebase の `GameCenterAuthProvider` 用 credential を作る
- Firebase Auth にサインイン、または匿名ユーザーへ link する

### 6.4 Boatface で次にやること

コード実装前に、まず以下を揃える:
- `stg` bundle ID に Game Center capability を追加
- 開発用 provisioning profile を更新
- シミュレータではなく実機で確認できる状態を用意

## 7. Play Games

Play Games は Android 専用。

### 7.1 Firebase Console

`Authentication > Sign-in method` で `Play Games` を有効化する。

### 7.2 Google Play Console

必要な前提:
- Play Games Services の game project を作成する
- テスターを登録する
- 必要な設定を publish する

注意:
- Google の案内では、Play Games Services の変更反映に最大 2 時間程度かかることがある

### 7.3 Android 側

Firebase Auth で Play Games を使うには、まず Google Play Games Services から OAuth 2.0 server auth code を取得する必要がある。

その後:
1. server auth code を取得する
2. `PlayGamesAuthProvider.credential(serverAuthCode: ...)` を作る
3. Firebase Auth にサインイン、または匿名ユーザーへ link する

### 7.4 Boatface で次にやること

コード実装前に、まず以下を揃える:
- `stg` 用の Play Games Services project
- Android テスター登録
- server auth code を取るための native / plugin 方針決定

補足:
- Play Games は Google provider と違い、Firebase だけでは完結しない
- Flutter 側は auth code 取得手段を別途選定する必要がある

## 8. 推奨の作業順

1. `Anonymous` を有効化して匿名ログインの確認を取る
2. `Google` を Firebase Console で有効化する
3. 新しい `GoogleService-Info.plist` / `google-services.json` を再生成する
4. iOS の `Info.plist` に Google Sign-In 用設定を入れる
5. Google ログインの実機確認を行う
6. Apple 側の capability と provisioning を整えて `Game Center` に進む
7. Google Play Console 側の準備を整えて `Play Games` に進む

## 9. 公式資料

Firebase:
- [Authenticate with Firebase anonymously (Flutter)](https://firebase.google.com/docs/auth/flutter/anonymous-auth)
- [Federated identity & social sign-in (Flutter)](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Account linking (Flutter)](https://firebase.google.com/docs/auth/flutter/account-linking)
- [Authenticate Using Game Center](https://firebase.google.com/docs/auth/ios/game-center)
- [Authenticate Using Google Play Games Services on Android](https://firebase.google.com/docs/auth/android/play-games)

Google / Android:
- [google_sign_in package](https://pub.dev/documentation/google_sign_in/latest/)
- [google_sign_in_ios package](https://pub.dev/packages/google_sign_in_ios)
- [google_sign_in_android package](https://pub.dev/documentation/google_sign_in_android/latest/)
- [Platform authentication for Play Games Services](https://developer.android.com/games/pgs/signin)
- [Test and publish your game](https://developer.android.com/games/pgs/console/publish)

Apple:
- [Game Center Overview](https://developer.apple.com/game-center/)
- [Capability and entitlement updates](https://developer.apple.com/help/account/reference/capability-entitlement-updates)
- [Working with Players in Game Center](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/GameKit_Guide/Users/Users.html)
