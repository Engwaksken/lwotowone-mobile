# Lwotowone — Flutter participant app

Separate Android/iOS source project connected to the Laravel CMS and learning API. Generated native projects are included. This package contains source, not a signed APK or IPA.

## Screens and functions

Participant login/registration, overview, searchable course catalogue, enrolment, downloaded lessons, protected resource downloads, written assignment submissions, practical activity logs, mentor profiles and booking requests, opportunities/applications, enterprise plans, income/expense records, events, email/in-app notice inbox, profile and pending synchronisation screen.

## Run on Windows / Android

Install Flutter, Android Studio/JDK and Android SDK. This build was analysed and tested with Flutter 3.47.6 / Dart 3.13.5. In the extracted `lwotowone-mobile` directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The app defaults to the official API at `https://cms.kemmytech.com/api`. To use another deployment, pass `--dart-define=API_BASE_URL=https://YOUR-DOMAIN/api`. Run the Laravel migrations and seed administrator first, then publish courses and register a participant. Administrators and staff use the web portal; mobile login is participant-only.

An Android emulator's host PC is typically reachable at `10.0.2.2`, but release builds use HTTPS. For a physical phone, deploy the API or use a reachable development HTTPS endpoint. Never enable broad cleartext traffic in a production release.

## Build

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://cms.kemmytech.com/api
flutter build appbundle --release --dart-define=API_BASE_URL=https://cms.kemmytech.com/api
```

Before distribution, review the included green-and-gold L lettermark or replace it with your approved brand icon, configure Android release signing (the generated project initially uses debug signing), review the application ID `ug.co.lwotowone.lwotowone_mobile`, and configure store metadata. For iOS, use macOS, CocoaPods and Xcode, choose your team and provisioning, then run `flutter build ipa` with the same API define. Review iOS bundle identifier and secure-storage keychain entitlements for your signing configuration.

## Offline behaviour

- First sign-in and enrolment need internet.
- Synchronise from the toolbar or pull to refresh. Opening the main screen also requests a sync.
- Course lesson text and account records persist in app-private storage. Tokens use OS secure storage.
- Documents and non-video lesson files synchronize for offline use. Video files are opt-in: tap **Download compressed video for offline** in a lesson to download and compress it to up to 540p. Videos over 100 MB are refused; removable downloads show their storage size. Streaming/external video links still require internet.
- Lesson completion, written assignments, practical logs and income/expense records can be queued offline.
- The queue persists across app restarts. UUIDs prevent server duplication after retry.
- A validation failure remains in Pending with the server's message. Retry or discard it; to change the contents, discard the failed item and submit a corrected one.
- Enrolment, mentor bookings, applications, new enterprises, event registrations and profile changes need an online server response.
- A pending action counts as saved locally until the server accepts it. The main dashboard reflects the last server snapshot rather than speculative totals.
- Sign out requires internet to revoke the token, clears account cache/resources and blocks while unsent work exists. Synchronise or individually discard pending work first.
- Expired tokens return to sign-in while retaining pending work for the same account. Signing into another account does not load the previous account's cache.
- Text/records are refreshed in a full snapshot; videos are not preloaded. The app has no automatic background sync and no device push integration.

Email notices are sent by the Laravel queue; mobile sees database notices on the next sync. The app does not deliver remote notifications while a device has no connectivity. Financial records are self-entered and do not process payments.

## Learner profile photos

From **Profile → Edit learner profile**, choose **Add or change photo** to select a JPG, PNG or WebP image (up to 5 MB). Uploading requires internet. Photos are stored privately and served only to the signed-in learner. Deploy the matching Laravel API update and run `php artisan migrate --force` before using photo uploads.

## Source map

- `lib/services/repository.dart`: API, token storage, snapshot persistence, offline queue, resource downloads.
- `lib/screens/login.dart`: participant sign-in, registration, terms and password reset link.
- `lib/screens/home.dart`: dashboard and participant module screens.
- `lib/screens/course.dart`: lessons, resources, submissions and web certificate link.
- `lib/screens/action_form.dart`: validated participant action forms.
- `test/`: widget and API error-handling tests.

Device acceptance: register, enrol, sync, turn off data, restart the app, read a lesson, queue a log, restore data, sync, verify the server record appears once, submit work, assess it on web, then sync feedback. Also test real resource opening, session expiry, cross-account isolation, low bandwidth and store-signed secure storage. Native Android/iOS builds and physical-device testing require your build environment and release credentials.

## Continued development: enterprise editing and APK automation

Enterprise cards now include Edit enterprise. Participants can update their business plan and stage online, while income entries remain attached to the same enterprise. Reporting filters work offline against the latest downloaded records: enterprise, all time, week, month, year and custom dates. Search matches transaction descriptions; totals use the reporting filters.

The app rejects missing, placeholder, non-HTTPS and credential-bearing API addresses before sending login details. Always provide a real API base URL ending in `/api`.

For a tested local APK build in PowerShell:

```powershell
cd D:\projects\lwotowone-mobile
.\scripts\build-apk.ps1 -ApiBaseUrl 'https://YOUR-ACTUAL-DOMAIN/api'
```

Replace the URL. The script checks dependencies, analysis and tests before building. Add `-RequireReleaseKey` to require production signing. Copy `android/key.properties.example` to `android/key.properties`, set your real key details and keep the keystore outside source control. Gradle uses the configured upload key when present; without it, local release builds still use debug signing for testing and the script says so.

After merging the workflow into the default branch, open GitHub **Actions → Flutter checks and test APK → Run workflow**. Enter your actual HTTPS API URL. The manual run builds a debug-signed test APK and uploads `lwotowone-test-apk`. Pushes and pull requests run analysis and tests without publishing an APK. This workflow does not publish to an app store.

The workflow pins Flutter 3.47.6. Production APK signing and physical-device acceptance remain separate from the test artifact. Official signing reference: https://docs.flutter.dev/deployment/android

## Learning progress and event update

Course cards and downloaded course pages show lesson completion, practical assessments passed and certificate readiness. The next incomplete lesson opens automatically when entering a course. Progress reflects the last confirmed snapshot; queued offline completions appear after successful synchronisation. Certificate links use the configured API host and require web sign-in.

Event screens display registration history, confirmation before cancellation, and re-registration after cancellation. Cancellation and registration require an online response. Start-time and capacity rules are enforced by Laravel. Synchronise after updating the web API so the app receives event eligibility fields. No dependency or native signing change is required by this update.

## Account email verification update

Mobile registration now handles the API's email-verification response without expecting an access token. The participant is returned to sign-in with a confirmation message and can sign in after verifying their email. Accounts provisioned by an administrator with a temporary password must first verify the email and change that temporary password on the website before mobile API sign-in is allowed. SMTP delivery and administrator-managed users/settings remain web-portal functions.

## Offline learning content

After payment/course access is confirmed, use **Synchronise** while connected to download authorized lesson text and downloadable lesson/resource files. They are stored per account and can be opened offline; lesson completions and written submissions can remain queued until the next successful sync. Locked content is not cached. Streaming videos and external links still require internet, and logging out removes that account's local cache.
