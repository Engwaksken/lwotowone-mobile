# Build validation — 4 October 2026

| Check | Result |
|---|---|
| Laravel dependency installation and Composer metadata | Passed; Laravel 13.34.0, Sanctum 4.3.3 |
| PHP source syntax | 34 source files, no errors |
| SQLite migration and seeding | Passed |
| Laravel feature tests | 13 tests, 75 assertions passed |
| Public and CMS/participant page rendering | Passed in feature tests |
| Browser homepage | HTTP 200, stylesheet loaded |
| Responsive homepage | Inspected at desktop and 390px mobile width; no horizontal overflow |
| Staff browser login and dashboard | Passed |
| Queue and scheduler command checks | Passed |
| Flutter dependencies | Resolved and locked |
| Flutter static analysis | No issues found |
| Flutter automated tests | 6 tests passed |
| Native APK / IPA compilation | Not run; Android SDK and Xcode release environment were not available |
| Production MySQL and SMTP delivery | Not tested against a live organisation server |

Laravel tests cover participant-only registration, inactive account rejection, CMS permissions, instructor ownership, enrolment-gated progress, duplicate-safe completion, mentorship exclusivity, income ownership and sync replay, event capacity, certificate requirements, draft exclusion, public/CMS/participant view rendering, private resource access and cancelled registration capacity.

Flutter tests cover empty login validation, all participant module screen rendering, API validation and malformed-response handling, offline queue persistence across restart, one replay after reconnection, failed-action retention and account cache isolation.

Offline tests use mocked HTTP responses and secure storage. Native device secure storage, external resource opening, actual low-bandwidth use, release signing and hardware-specific behaviour still require device acceptance testing. The complete acceptance scenario is in the mobile README.

Web screenshot files in `docs/screenshots` show a locally seeded demo, not measured impact or live deployment data.
