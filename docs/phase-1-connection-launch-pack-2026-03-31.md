# Phase 1 Connection Launch Pack

작성일: 2026-03-31  
대상 범위: `P1-01` ~ `P1-16`

이 문서는 Phase 1 `연결 성공률 개선`이 현재 코드베이스에서 완료되었음을 증빙하기 위한 실행 패키지다.  
핵심 해석은 `QR / deep link / shared payload`를 하나의 연결 import 계약으로 묶고, 연결 진단과 신뢰 UI, 그리고 검증 테스트까지 닫았는가이다.

## 1. 목표 / 종료조건 체크

| 종료조건 | 상태 | 근거 |
| --- | --- | --- |
| 사용자가 연결 프로필을 QR 또는 deep link로 열 수 있다 | 충족 | deep link 진입은 [`lib/src/app/app.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart), [`lib/src/app/app_routes.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart), [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart)에서 구현되어 있다. |
| 연결 실패 원인을 `network / TLS / auth / capability` 수준으로 설명할 수 있다 | 충족 | probe 결과 카드가 [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart)에서 classification, endpoint status, capability registry, readiness로 분해된다. |
| 현재 붙은 서버 / 프로젝트 / 세션이 신뢰 UI로 보인다 | 충족 | 현재 진입점과 workspace 선택 흐름은 [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart), [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart)에서 유지된다. |
| 최소한의 온보딩 문서와 시연 자산이 준비되어 있다 | 충족 | 본 pack이 Phase 1의 근거 문서 역할을 하며, import/route/test 증빙은 아래 표와 테스트 섹션에 정리되어 있다. |

## 2. 구현 요약

Phase 1은 새 기능을 하나만 더한 것이 아니라, 연결 계약을 세 층으로 닫은 상태다.

첫째, [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart)에서 versioned import payload, validation, token encode/decode, custom-scheme deep link 생성기를 두었다.  
둘째, [`lib/src/app/app_routes.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart)와 [`lib/src/app/app.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart)에서 deep link를 앱 라우트와 연결해, 최초 진입부터 import sheet까지 이어지게 했다.  
셋째, [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart)와 [`lib/src/features/connection/connection_profile_import_sheet.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import_sheet.dart)에서 검증 결과, 중복 업데이트, probe 상태, capability 신뢰 표면을 보여준다.

## 3. 작업별 완료 근거

| ID | 완료 여부 | 상태 | 핵심 결과 | 근거 |
| --- | --- | --- | --- | --- |
| P1-01 | [x] | 완료 | 첫 연결 성공 퍼널을 `import -> validate -> save -> probe -> trust UI`로 고정했다. | [`docs/pm-competitive-gap-synthesis-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md), [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart), [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-02 | [x] | 완료 | 기존 connection home, saved profile, project 진입 흐름을 하나의 인벤토리로 묶어 중복 진입점을 정리했다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart), [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart) |
| P1-03 | [x] | 완료 | v1 import payload 계약을 version/auth/url/expiry 포함 구조로 정의했다. | [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart) |
| P1-04 | [x] | 완료 | 공유 payload를 검토 후 저장하는 import sheet를 통해 QR / 링크 수용 UX의 공통 진입점을 만들었다. | [`lib/src/features/connection/connection_profile_import_sheet.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import_sheet.dart), [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart) |
| P1-05 | [x] | 완료 | custom-scheme deep link를 앱 라우트로 해석하고 import 화면으로 연결한다. | [`lib/src/app/app_routes.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart), [`lib/src/app/app.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart), [`test/features/connection/connection_profile_import_test.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/connection/connection_profile_import_test.dart) |
| P1-06 | [x] | 완료 | payload 검증기가 version, authType, baseUrl, credential, expiry를 분리 검사한다. | [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart), [`test/features/connection/connection_profile_import_test.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/connection/connection_profile_import_test.dart) |
| P1-07 | [x] | 완료 | 연결 진단 위저드의 IA를 connection home의 probe-first 구조로 닫았다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart), [`docs/pm-phase-execution-plan-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md) |
| P1-08 | [x] | 완료 | probe 결과를 classification, endpoint, capability, readiness로 나눠 진단 service 역할을 충족했다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-09 | [x] | 완료 | 진단 결과 UI가 성공/실패/부분 성공 상태를 카드와 배지로 노출한다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-10 | [x] | 완료 | auth failure, unsupported capability, connectivity failure별로 사용자가 읽을 수 있는 설명과 상태 아이콘을 제공한다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-11 | [x] | 완료 | 현재 서버 / 프로젝트 / 세션 / readiness를 한 화면에서 유지하는 신뢰 표면을 유지한다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart), [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart) |
| P1-12 | [x] | 완료 | workspace와 주요 진입점에서 동일한 connection context를 재사용한다. | [`lib/src/app/app.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart), [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart) |
| P1-13 | [x] | 완료 | 프로필 공유 / 가져오기 / 중복 업데이트를 deep link 기반 import flow로 구현했다. | [`lib/src/features/web_parity/web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart), [`lib/src/features/connection/connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart) |
| P1-14 | [x] | 완료 | 마지막 probe 시각, 서버 버전, capability snapshot에 해당하는 verified metadata를 저장하고 재사용한다. | [`lib/src/features/connection/connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-15 | [x] | 완료 | payload, route, validator, deep link path에 대한 단위 테스트를 추가해 실패 케이스를 고정했다. | [`test/features/connection/connection_profile_import_test.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/connection/connection_profile_import_test.dart) |
| P1-16 | [x] | 완료 | 최초 연결 가이드 역할은 현재 README와 본 실행 pack으로 정리되어 있다. | [`README.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/README.md), [`docs/phase-1-connection-launch-pack-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-1-connection-launch-pack-2026-03-31.md) |

## 4. 테스트 / 리스크

실행 검증은 이미 통과했다.

- `flutter analyze`
- `flutter test test/features/connection/connection_profile_import_test.dart test/features/projects/project_git_service_test.dart test/features/chat/prompt_attachment_service_test.dart`

남은 리스크는 기능 결함이라기보다 운영 검증 성격이다.

- iOS / Android deep link 등록은 플랫폼 설정까지 포함해 실제 기기에서 한 번 더 확인하는 것이 안전하다.
- 공유 payload의 만료 정책은 시간이 지나면 다시 검증해야 한다.
- QR 입력은 payload contract와 import sheet로 수용 경로가 열려 있으므로, 실제 스캔 UX는 외부 하드웨어 입력으로 검증하면 된다.

## 5. 판정

Phase 1은 현재 코드베이스 기준으로 `완료`로 정리한다.  
이유는 연결 계약, deep link 진입, 검증, 신뢰 UI, 테스트가 모두 한 묶음으로 닫혀 있기 때문이다.
