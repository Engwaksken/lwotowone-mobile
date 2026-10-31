# Lwotowone — Flutter participant app

Separate Android/iOS source project connected to the Laravel CMS and learning API. Generated native projects are included. This package contains source, not a signed APK or IPA.

## Screens and functions

The app uses a five-tab institute layout:

- **Home**: greeting, "Continue learning" card with progress, course/lesson/certificate counts, and a "For you" list (approved downloads, pending requests, unsent work, event registrations, announcements).
- **Courses**: *My courses* with progress, and *Browse* to send an enrollment request for another course (admins approve or reject on the website).
- **Activities**: practical logs, mentorship, opportunities, enterprise and earnings, events and the knowledge game.
- **Inbox**: notices from the institute, and work waiting to synchronise.
- **Profile**: learner profile, learning language, course and download requests, files saved in the app, sign out.

Lessons open on their own page with in-app video/audio playback, an in-app PDF reader, images and text. Learners only see content in the learning language chosen at sign-up (English or Luganda).

## Run on Windows / Android

Install Flutter, Android Studio/JDK and Android SDK. This build was analysed and tested with Flutter 3.47.6 / Dart 3.13.5. In the extracted `lwotowone-mobile` directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The app defaults to the official API at `https://www.lwotowone.com/api`. To use another deployment, pass `--dart-define=API_BASE_URL=https://YOUR-DOMAIN/api`. Run the Laravel migrations and seed administrator first, then publish courses and register a participant. Administrators and staff use the web portal; mobile login is participant-only.

An Android emulator's host PC is typically reachable at `10.0.2.2`, but release builds use HTTPS. For a physical phone, deploy the API or use a reachable development HTTPS endpoint. Never enable broad cleartext traffic in a production release.

## Build

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://www.lwotowone.com/api
flutter build appbundle --release --dart-define=API_BASE_URL=https://www.lwotowone.com/api
```

Before distribution, review the included green-and-gold L lettermark or replace it with your approved brand icon, configure Android release signing (the generated project initially uses debug signing), review the application ID `ug.co.lwotowone.lwotowone_mobile`, and configure store metadata. For iOS, use macOS, CocoaPods and Xcode, choose your team and provisioning, then run `flutter build ipa` with the same API define. Review iOS bundle identifier and secure-storage keychain entitlements for your signing configuration.

## Offline behaviour and downloads

- First sign-in, enrollment requests and download requests need internet.
- Synchronise from the toolbar or pull to refresh. Opening the app also requests a sync.
- Course lesson text and account records persist in app-private storage. Tokens use OS secure storage.
- Videos, audio, PDFs and images play inside the app, streamed from the server with the learner's sign-in. Nothing is saved automatically and files are never handed to other apps.
- To keep a lesson or resource for offline use, the learner taps **Request download**. When an admin approves it on the website, **Save in the app** appears; an approval allows 3 downloads within 7 days. A lesson's approval also covers its attached files. Saved copies open only inside the app and are listed under Profile → Saved in the app.
- Saved copies stay after the approval runs out, but are removed on the next sync if an admin withdraws the approval or the learner loses access to the content. Files saved automatically by earlier app versions are removed on the first sync.
- Lesson completion, written assignments, practical logs and income/expense records can be queued offline.
- The queue persists across app restarts. UUIDs prevent server duplication after retry.
- A validation failure stays in Inbox → Waiting to sync with the server's message. Retry or discard it; to change the contents, discard the failed item and submit a corrected one.
- Mentor bookings, applications, new enterprises, event registrations and profile changes need an online server response.
- Sign out requires internet to revoke the token, clears the account's records and saved files, and blocks while unsent work exists.
- Expired tokens return to sign-in while retaining pending work for the same account. Signing into another account does not load the previous account's cache.
- The app has no automatic background sync.

The matching Laravel API must include the enrollment request, download request and `/api/downloads/{id}` endpoints; run `php artisan migrate --force` on the server before releasing this app version.

## Learner profile photos

From **Profile → Edit learner profile**, choose **Add or change photo** to select a JPG, PNG or WebP image (up to 5 MB). Uploading requires internet. Photos are stored privately and served only to the signed-in learner. Deploy the matching Laravel API update and run `php artisan migrate --force` before using photo uploads.

## Source map

- `lib/theme.dart`: brand colours and app theme.
- `lib/services/repository.dart`: API, token storage, snapshot persistence, offline queue, requests, streaming and approved downloads.
- `lib/screens/login.dart`: participant sign-in, registration (including learning language), terms and password reset link.
- `lib/screens/home.dart`: the five-tab shell and Home tab.
- `lib/screens/courses.dart`, `course.dart`, `content.dart`: course catalogue and requests, course page, lesson/resource page.
- `lib/screens/activities.dart`, `inbox.dart`, `profile_tab.dart`: the other tabs.
- `lib/widgets/media_view.dart`: in-app video/audio player, PDF reader, image and text viewers.
- `lib/widgets/download_panel.dart`: download request, approval and saving.
- `lib/screens/action_form.dart`: validated participant action forms.
- `test/`: widget, offline and API error-handling tests.

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
