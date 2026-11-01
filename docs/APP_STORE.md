# App Store Connect — Adisyon Yönetim

Bundle ID: `com.adisyonyonetim.app`  
SKU / product name: `AdisyonYonetim`  
Display name: Adisyon Yönetim

Use this file when creating the App Store listing. Replace `[REVIEW_DEMO_*]` placeholders before submitting.

---

## Türkçe

**Alt başlık (30)**  
Restoran masa ve adisyon

**Tanıtım metni (170)**  
Masaları, mutfağı ve kasayı tek uygulamada yönetin. Personel PIN veya e-posta ile giriş, canlı adisyon ve ödeme takibi.

**Açıklama**  
Adisyon Yönetim, kafe ve restoran personeli için masa, mutfak ve kasa uygulamasıdır.

• Masaları görüntüleyin, adisyon açın ve ürün ekleyin  
• Mutfak (KDS) kuyruğunu canlı izleyin ve siparişleri ilerletin  
• Nakit veya kart ödemesi alın, hesabı kapatın  
• Günlük kasa özetini görün  
• E-posta veya işletme kodu + personel PIN ile giriş yapın  

Uygulama yalnızca işletmenizin Adisyon Yönetim hesabına bağlı personel içindir. Misafir siparişi veya genel tüketici kullanımı yoktur.

**Anahtar kelimeler (100)**  
adisyon,restoran,kafe,masa,mutfak,kasa,garson,pos,sipariş,ödeme

---

## English

**Subtitle (30)**  
Restaurant floor & checks

**Promotional text (170)**  
Run tables, kitchen, and cash drawer in one app. Staff PIN or email sign-in, live checks, and payments.

**Description**  
Adisyon Yönetim is a staff app for cafés and restaurants to manage tables, kitchen tickets, and the cash drawer.

• View tables, open checks, and add menu items  
• Watch the kitchen (KDS) queue and bump tickets  
• Take cash or card payments and close the check  
• See a daily cash summary  
• Sign in with email or business code + staff PIN  

The app is only for staff linked to your Adisyon Yönetim business account. It is not a consumer ordering app.

**Keywords (100)**  
restaurant,pos,tables,kitchen,waiter,cafe,check,orders,payment,staff

---

## App Privacy answers

Tracking: **No**. No tracking domains.

| Data type | Linked to user | Used for tracking | Purposes |
|---|---|---|---|
| Name | Yes | No | App Functionality |
| Email Address | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Purchase History | Yes | No | App Functionality |
| Device ID | Yes | No | App Functionality |

Collected for staff login, check/payment operations, and (when push is enabled) device registration. Not sold. See PrivacyInfo.xcprivacy and https://adisyonyonetim.com.tr/gizlilik

Required Reason API: UserDefaults **CA92.1** (theme, KDS station — app-only defaults). No disk-space, boot-time, file-timestamp, or active-keyboard APIs.

---

## Review notes template

```
App type: staff POS for restaurants (not a consumer storefront).
Sign-in: PIN tab → business code + staff PIN, or Email tab.

Demo account (replace before submit):
  Email:            [REVIEW_DEMO_EMAIL]
  Password:         [REVIEW_DEMO_PASSWORD]
  Business code:    [REVIEW_DEMO_BUSINESS_SLUG]
  Staff PIN:        [REVIEW_DEMO_PIN]

Suggested path:
  1. Sign in with the demo account.
  2. Select a branch if asked.
  3. Open a table → add an item → send to kitchen.
  4. Kitchen tab: bump a ticket.
  5. Take a payment (cash) and close the check.
  6. Settings → About for privacy / account-deletion links.

Push notifications are OFF (PUSH_ENABLED=NO). No APNs entitlement or
remote-notification background mode is included in this build.
```

---

## Screenshot list

Capture on iPhone 6.7" and iPad 13" (and 6.5" if still required). No demo-kafe text in the UI.

| # | Screen | Notes |
|---|---|---|
| 1 | Login (e-posta) | Empty fields, no prefills |
| 2 | Login (PIN) | Placeholder “işletme kodunuz”, empty code |
| 3 | Masalar | Occupied and empty tables |
| 4 | Adisyon / sipariş | Line items and totals |
| 5 | Mutfak (KDS) | Queue with statuses |
| 6 | Kasa | Daily summary |
| 7 | Ayarlar | Account + branch |
| 8 | Hakkında | Version + gizlilik / KVKK / hesap-silme / destek |

---

## Links

- Privacy: https://adisyonyonetim.com.tr/gizlilik
- KVKK: https://adisyonyonetim.com.tr/kvkk
- Account deletion: https://adisyonyonetim.com.tr/hesap-silme
- Support: https://adisyonyonetim.com.tr/destek
