# Lwotowone learning progress and events update

Apply this update after the enterprise/earnings development update delivered previously. This ZIP contains complete replacement files and new files, not a new application.

1. Back up or commit your local project changes.
2. Extract this ZIP to a temporary folder.
3. Copy the included project folders and README.md / VALIDATION.md into your existing project, preserving their paths and replacing the corresponding files. Review any local edits before replacing a file.
4. Run the checks below. No database migration is required.

Project: D:\projects\lwotowone-mobile

```powershell
Set-Location D:\projects\lwotowone-mobile
flutter pub get
flutter analyze
flutter test
.\scripts\build-apk.ps1 -ApiBaseUrl "https://YOUR-ACTUAL-HOST/api"
```

Replace the URL with the actual deployed Laravel HTTPS API URL. For production signing, follow the existing mobile README and use -RequireReleaseKey. The app must synchronise after the web API update to receive current event status. Progress uses the last downloaded confirmed data; pending offline work counts after successful synchronisation.

The Android release-mode APK was built successfully at `build/app/outputs/flutter-apk/app-release.apk` for `https://cms.kemmytech.com/api`. It uses debug signing because no release key is configured. Install/device acceptance testing and production signing remain outstanding.

Updated files:

- README.md
- VALIDATION.md
- lib/screens/course.dart
- lib/screens/home.dart
- lib/screens/learning_progress.dart
- lib/services/course_progress.dart
- test/course_progress_test.dart
- test/learning_events_widget_test.dart
