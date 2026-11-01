# Adisyon Yönetim — iOS

Native SwiftUI uygulaması (iOS 16+, Swift 5.9+). MVVM, async/await `URLSession`, Keychain'de oturum, polling ile canlı güncelleme.

## Gereksinimler (Mac)
- Xcode 15+ (iOS 16 SDK ve üzeri)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Apple Developer hesabı (cihazda çalıştırma / App Store için)

## Projeyi oluşturma
```bash
cd apps/ios
xcodegen generate          # AdisyonYonetim.xcodeproj üretir (git'e eklenmez)
open AdisyonYonetim.xcodeproj
```

## İmzalama
1. Xcode → target **AdisyonYonetim** → *Signing & Capabilities*.
2. *Team* seçin (veya `project.yml` içindeki `DEVELOPMENT_TEAM` değerini doldurup `xcodegen generate` tekrar çalıştırın).
3. Bundle id: `com.adisyonyonetim.app` (Developer portalda App ID olarak kayıtlı olmalı; push kullanılacaksa *Push Notifications* yetkisi açık olmalı).

## Yapılandırma
`project.yml` → `settings.base`:
| Anahtar | Varsayılan | Açıklama |
|---|---|---|
| `API_BASE_URL` | `https://api.adisyonyonetim.com.tr/api` | API kök adresi (Info.plist'e aktarılır) |
| `PUSH_ENABLED` | `NO` | `YES` olunca APNs kaydı + `POST /api/devices` (platform `ios`) |

## Push bildirimleri (opsiyonel)
Push varsayılan olarak **kapalıdır** (`PUSH_ENABLED: "NO"`). Bu durumda:
- `Info.plist` / `project.yml` içinde `UIBackgroundModes` **yoktur**
- `AdisyonYonetim.entitlements` **boştur** (`aps-environment` yok)

Açmak için (üçü birden):
1. `project.yml` → target settings `PUSH_ENABLED: "YES"`
2. `project.yml` → `info.properties` altına `UIBackgroundModes: [remote-notification]` ekleyin (Info.plist ile aynı)
3. `AdisyonYonetim.entitlements` içine `aps-environment` ekleyin (`development`; App Store için `production`)
4. **Firebase (FCM) kullanılacaksa:** Xcode → *File → Add Package Dependencies* → `https://github.com/firebase/firebase-ios-sdk`, `FirebaseMessaging` ürününü ekleyin. Firebase konsolundan iOS uygulaması (`com.adisyonyonetim.app`) oluşturup **GoogleService-Info.plist** dosyasını indirin ve `AdisyonYonetim/Resources/` altına koyun (target'a dahil edin; `.gitignore`'da, repoya eklenmez). APNs Auth Key'i (.p8) Firebase → Project Settings → Cloud Messaging'e yükleyin.
5. Firebase eklenmezse uygulama ham APNs token'ını `/api/devices`'a gönderir.

## Çalıştırma
Simülatör veya cihaz seçip ⌘R. PIN alanında işletme kodu **önceden doldurulmaz**; yer tutucu `işletme kodunuz`. İnceleme hesabı için `docs/APP_STORE.md`.

## Arşivleme / dağıtım
```bash
xcodebuild -project AdisyonYonetim.xcodeproj -scheme AdisyonYonetim \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/AdisyonYonetim.xcarchive archive
xcodebuild -exportArchive -archivePath build/AdisyonYonetim.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
```
veya Xcode → *Product → Archive* → *Distribute App* (TestFlight/App Store Connect).

## İkonlar
`python3 scripts/generate_icons.py /path/to/logo.jpg` (Pillow) — AppIcon seti, LaunchLogo ve renk setlerini yeniden üretir.

## Yapı
- `Core/` — APIClient (token yenileme), Endpoints, TokenStore (Keychain), NetworkMonitor, Poller, Theme, Formatters
- `Models/` — API ile birebir Codable modeller
- `Features/` — Auth, Branch, Tables, Order, Kitchen, Cash, Settings
- `Push/` — PushManager (bayrak arkasında)
