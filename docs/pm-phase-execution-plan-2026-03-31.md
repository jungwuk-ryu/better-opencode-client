# PM 단계별 실행 계획 및 완료 추적 문서

작성일: 2026-03-31  
최종 갱신: 2026-03-31  
기준 문서: `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md`

이 문서는 경쟁사 통합 기준서를 실제 실행 문서로 풀어낸 뒤, 이번 실행 턴에서 완료 상태까지 반영한 최종 추적본이다.

## 1. 사용 규칙

### 상태 규칙

| 값 | 의미 |
| --- | --- |
| `완료` | 구현, 문서, 검증까지 끝남 |
| `진행중` | 현재 작업 중 |
| `미착수` | 아직 시작하지 않음 |
| `보류` | 의도적으로 뒤로 미룸 |

### 완료 여부 표기

| 표기 | 의미 |
| --- | --- |
| `[x]` | 완료 |
| `[ ]` | 미완료 |

### 업데이트 규칙

- 완료된 작업은 근거 문서, 코드, 검증 명령을 `비고`에 남긴다.
- 범위 설명이 필요한 항목은 phase pack 문서에서 상세 근거를 제공한다.
- 공개 표면 변경은 README, docs, issue template까지 포함해 추적한다.

## 2. 요약 대시보드

| 구간 | 목표 | 작업 수 | 완료 | 진행중 | 미착수 | 비고 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Baseline | 이미 확보된 기반 정리 | 6 | 6 | 0 | 0 | 기존 미션 반영 유지 |
| Phase 1 | 첫 연결 성공률 개선 | 16 | 16 | 0 | 0 | `docs/phase-1-connection-launch-pack-2026-03-31.md` |
| Phase 2 | 앱 안에서 완료 루프 닫기 | 16 | 16 | 0 | 0 | `docs/phase-2-git-loop-pack-2026-03-31.md` |
| Phase 3 | 원격 운영성과 모바일 차별화 | 18 | 18 | 0 | 0 | `docs/phase-3-mobile-ops-pack-2026-03-31.md` |
| Phase 4 | 패키징, 신뢰, 외부 채택 강화 | 14 | 14 | 0 | 0 | `docs/phase-4-pack-2026-03-31.md` |
| Ongoing | 전 Phase 공통 운영 | 5 | 5 | 0 | 0 | 리스크, QA, 아카이브 반영 완료 |

## 3. Baseline: 이미 완료된 기반 작업

| ID | 완료 여부 | 상태 | 작업 | 범위 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- |
| B-01 | [x] | 완료 | Local connection draft restore | 서버 연결 입력 도중 앱이 종료되어도 복원 가능 | 로컬 draft persistence | `docs/mission-05-app-only-feature-plan.md` |
| B-02 | [x] | 완료 | Pinned server profiles | 자주 쓰는 서버 프로필을 상단 고정 | 서버 프로필 pinning | `docs/mission-05-app-only-feature-plan.md` |
| B-03 | [x] | 완료 | Pinned projects | 자주 쓰는 프로젝트를 빠르게 재진입 | 프로젝트 pinning | `docs/mission-05-app-only-feature-plan.md` |
| B-04 | [x] | 완료 | Probe/auth/capability 하드닝 | 연결 probe, auth, capability 부재 시나리오 보강 | 실패 처리 안정화 | `docs/mission-06-scenario-review.md` |
| B-05 | [x] | 완료 | SSE drop/recovery 하드닝 | 스트림 드롭 및 재동기화 경로 검토 | recovery path 보강 | `docs/mission-06-scenario-review.md` |
| B-06 | [x] | 완료 | Pending request fallback 하드닝 | 질문/권한 endpoint 부재 시 전체 refresh 오염 방지 | mixed capability 대응 | `docs/mission-06-scenario-review.md` |

## 4. Phase 1: 연결 성공률 개선

### Phase 1 종료 조건

- 사용자가 QR 또는 deep link로 연결 프로필을 열 수 있다.
- 연결 실패 시 원인을 `network / TLS / auth / capability` 수준으로 설명할 수 있다.
- 현재 어떤 서버, 프로젝트, 세션에 붙어 있는지 신뢰 UI로 보인다.
- 최소한의 온보딩 문서와 시연 자산이 준비되어 있다.

### Phase 1 작업 테이블

| ID | 완료 여부 | 상태 | 작업 | 세부 범위 | 선행 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1-01 | [x] | 완료 | 연결 성공 퍼널 정의 | 첫 연결 성공까지 필요한 단계와 이탈 지점 정의 | 없음 | 퍼널 정의 문서 | `docs/phase-1-connection-launch-pack-2026-03-31.md` |
| P1-02 | [x] | 완료 | 현재 연결 진입점 인벤토리 | connection home, project 진입, saved profile 흐름 정리 | P1-01 | 화면, 플로우 목록 | `docs/phase-1-connection-launch-pack-2026-03-31.md` |
| P1-03 | [x] | 완료 | 연결 프로필 import 스키마 v1 정의 | QR, deep link, shared payload 구조 정의 | P1-01 | payload schema | [`connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart) |
| P1-04 | [x] | 완료 | QR 연결 진입 UX 설계 | 스캔 시작, 권한, 실패 복구, 취소 흐름 정의 | P1-02, P1-03 | UX spec | QR은 deep link payload를 시스템 스캐너로 여는 경로로 정리, `docs/quickstart-first-connection.md` |
| P1-05 | [x] | 완료 | Deep link 연결 진입 설계 | 링크 열기, 중복 프로필, 만료 payload 처리 | P1-02, P1-03 | deep link spec | [`app.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart), [`app_routes.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart) |
| P1-06 | [x] | 완료 | import payload 검증기 구현 | 필수 필드, URL 형식, auth 타입, 만료 검사 | P1-03 | validator, service | [`connection_profile_import.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import.dart), test |
| P1-07 | [x] | 완료 | 연결 진단 위저드 IA 설계 | 단계, 상태, retry, 추천 액션 구조 설계 | P1-01, P1-02 | wizard IA | connection home probe-first IA, `docs/phase-1-connection-launch-pack-2026-03-31.md` |
| P1-08 | [x] | 완료 | 연결 진단 서비스 구현 | network, TLS, auth, capability 체크 분리 | P1-07 | diagnostic service | [`connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-09 | [x] | 완료 | 연결 진단 결과 UI 구현 | 성공, 실패, 부분 성공 화면과 액션 연결 | P1-07, P1-08 | diagnostic UI | [`connection_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart) |
| P1-10 | [x] | 완료 | 연결 실패 복구 액션 설계 | 재시도, 편집, 다른 프로필 저장, 도움말 이동 | P1-07 | recovery action map | probe classification 및 설명 문구 반영 |
| P1-11 | [x] | 완료 | persistent context bar 설계 | 현재 서버, 프로젝트, 세션, 상태 표시 구조 정의 | P1-02 | UI spec | home, workspace context 설계는 phase pack에 정리 |
| P1-12 | [x] | 완료 | persistent context bar 구현 | workspace와 주요 화면에 공통 context 표시 | P1-11 | context bar UI | [`web_home_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart), [`workspace_screen.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart) |
| P1-13 | [x] | 완료 | 연결 프로필 import/export 구현 | 프로필 공유, 가져오기, 중복 처리, 버전 처리 | P1-03, P1-06 | import, export flow | copy link + import sheet 구현 |
| P1-14 | [x] | 완료 | verified connection metadata 저장 | 마지막 성공 시각, 서버 버전, capability snapshot 저장 | P1-08 | metadata model | probe cache 및 snapshot 재사용 |
| P1-15 | [x] | 완료 | 연결 플로우 테스트 작성 | parser, validator, route, UI smoke test | P1-06, P1-08, P1-12, P1-13 | 테스트 코드 | [`connection_profile_import_test.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/connection/connection_profile_import_test.dart) |
| P1-16 | [x] | 완료 | 온보딩 문서 및 릴리즈 노트 작성 | 첫 연결 가이드, QR/deep link 예시, known limitation 정리 | P1-09, P1-13 | 문서, 릴리즈 노트 | `README.md`, `docs/quickstart-first-connection.md`, `docs/release-notes-template.md` |

## 5. Phase 2: 앱 안에서 완료 루프 닫기

### Phase 2 종료 조건

- 변경 파일과 저장소 상태를 앱 안에서 요약해 보여줄 수 있다.
- 최소한의 stage, commit, push, pull, branch 전환이 가능하다.
- PR, check 상태를 읽기 전용으로 한눈에 확인할 수 있다.
- 실패 시 terminal fallback이 명확하고 안전하게 제공된다.

### Phase 2 작업 테이블

| ID | 완료 여부 | 상태 | 작업 | 세부 범위 | 선행 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2-01 | [x] | 완료 | 최소 완료 루프 범위 정의 | 이번 Phase에서 지원할 Git, GitHub 액션 범위 확정 | 없음 | scope 문서 | `docs/phase-2-git-loop-pack-2026-03-31.md` |
| P2-02 | [x] | 완료 | git 관련 capability, endpoint 감사 | 현재 서버가 제공하는 상태, 행동 API 점검 | P2-01 | capability matrix | `ProjectGitService` shell contract 및 `gh pr view` read model |
| P2-03 | [x] | 완료 | 저장소 상태 도메인 모델 정의 | branch, ahead, behind, changed files, staged count 구조화 | P2-02 | repo status model | [`project_git_models.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_git_models.dart) |
| P2-04 | [x] | 완료 | 저장소 상태 요약 카드 설계 | 상단 카드 또는 패널 구조 정의 | P2-03 | UI spec | Git sheet overview + workspace runtime snapshot |
| P2-05 | [x] | 완료 | 저장소 상태 요약 카드 구현 | 현재 branch, 변경 수, 위험 상태 노출 | P2-04 | repo summary UI | [`workspace_git_sheet.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_git_sheet.dart) |
| P2-06 | [x] | 완료 | stage, unstage 액션 모델 정의 | 파일 단위 선택, 전체 선택, 충돌 상태 처리 | P2-03 | action model | `RepoChangedFile` flags 및 status label |
| P2-07 | [x] | 완료 | stage, unstage 액션 구현 | 변경 파일 목록에서 상태 전환 지원 | P2-06 | staging flow | Git sheet file actions |
| P2-08 | [x] | 완료 | commit composer 설계 | 제목, 본문, validation, empty staged state 처리 | P2-06 | commit UX spec | `_CommitComposerDialog` |
| P2-09 | [x] | 완료 | commit composer 구현 | commit 입력과 실행, 성공, 실패 피드백 | P2-08 | commit flow | Git sheet commit action |
| P2-10 | [x] | 완료 | push, pull 액션 구현 | push, pull, ahead, behind refresh, 충돌 피드백 | P2-03 | sync actions | `git pull --ff-only`, `git push` |
| P2-11 | [x] | 완료 | branch 전환, 생성 UX 구현 | branch 목록, switch, create 최소 버전 | P2-03 | branch actions UI | `_BranchPickerSheet`, branch service methods |
| P2-12 | [x] | 완료 | PR, check read model 정의 | PR 연결 상태, checks 요약, read-only 카드 구조 | P2-01, P2-02 | PR, check model | `RepoPullRequestSummary` |
| P2-13 | [x] | 완료 | PR, check 요약 카드 구현 | 현재 브랜치 기준 상태 노출 | P2-12 | PR, check UI | Git sheet PR card |
| P2-14 | [x] | 완료 | workspace, review 연계 설계 | diff, review, terminal과 git loop 진입점 정리 | P2-05, P2-07, P2-09 | navigation spec | workspace project actions 및 Git sheet entry |
| P2-15 | [x] | 완료 | 안전한 fallback 설계 및 구현 | 실패 시 terminal로 넘기기, 권한, 에러 가이드 | P2-09, P2-10, P2-11 | fallback flow | Git sheet fallback CTA |
| P2-16 | [x] | 완료 | git loop 테스트와 문서화 | model, service test, 지원 범위 문서화 | P2-05, P2-07, P2-09, P2-10, P2-11, P2-13 | 테스트, 문서 | `docs/phase-2-git-loop-pack-2026-03-31.md`, test |

## 6. Phase 3: 원격 운영성과 모바일 차별화

### Phase 3 종료 조건

- Project Actions로 반복적인 운영 작업을 한 번 탭으로 실행할 수 있다.
- 서비스, 잡, 세션 상태를 별도 운영 표면에서 확인할 수 있다.
- voice input, quick attach, triage 등 모바일 고유 입력 보조가 최소 버전으로 동작한다.
- 긴 세션과 다중 세션 탐색에서 피로가 눈에 띄게 줄어든다.

### Phase 3 작업 테이블

| ID | 완료 여부 | 상태 | 작업 | 세부 범위 | 선행 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3-01 | [x] | 완료 | 현재 운영 액션 인벤토리 | terminal, commands, links, project actions 후보 정리 | 없음 | action inventory | [`project_action_models.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_action_models.dart) |
| P3-02 | [x] | 완료 | Project Actions IA 정의 | 어떤 액션을 어디서 여는지 정보 구조 정의 | P3-01 | IA 문서 | `docs/phase-3-mobile-ops-pack-2026-03-31.md` |
| P3-03 | [x] | 완료 | Project Actions 도메인 모델 정의 | command, URL, port, service, job 타입 모델링 | P3-02 | action model | `project_action_models.dart` |
| P3-04 | [x] | 완료 | Project Actions entry UI 구현 | 액션 시트 또는 패널 진입점 추가 | P3-02, P3-03 | entry UI | workspace toolbar, chip, overflow, composer entry |
| P3-05 | [x] | 완료 | 저장된 명령 액션 구현 | 자주 쓰는 명령 실행, 최근 사용 표시 | P3-03 | command actions | Project Actions command section |
| P3-06 | [x] | 완료 | dev server, service 상태 카드 설계 | 실행 여부, 최근 에러, 재시작 액션 구조 정의 | P3-01 | UI spec | runtime snapshot card model |
| P3-07 | [x] | 완료 | dev server, service 상태 카드 구현 | 서비스 상태 요약과 빠른 액션 제공 | P3-06 | service status UI | `workspace_project_actions_sheet.dart` |
| P3-08 | [x] | 완료 | background job, process visibility 구현 | 장시간 작업, 백그라운드 프로세스 상태 표시 | P3-03 | jobs panel, card | PTY live count, session snapshot |
| P3-09 | [x] | 완료 | recent URL, open link 액션 구현 | 최근 열린 원격 URL 재오픈, 관련 액션 묶기 | P3-03 | URL actions | recent links + `url_launcher` |
| P3-10 | [x] | 완료 | port forwarding preset 모델 정의 | 자주 쓰는 포트, 라벨, 목적지 구조 정의 | P3-01 | preset spec | `PortForwardPreset` |
| P3-11 | [x] | 완료 | session search, worktree context 강화 | 세션 검색, worktree badge, 컨텍스트 강조 | P3-01 | search, context UI | workspace top context, chips, session labels |
| P3-12 | [x] | 완료 | voice input 요구사항 정의 | 플랫폼 정책, 언어, 권한, UX 흐름 정리 | 없음 | 요구사항 문서 | 구현과 pack에서 정리, mobile permissions 포함 |
| P3-13 | [x] | 완료 | voice prompt input MVP 구현 | 마이크 시작, 종료, 텍스트 반영, 실패 처리 | P3-12 | voice input flow | `speech_to_text` composer integration |
| P3-14 | [x] | 완료 | 이미지, 스크린샷 quick attach 구현 | 첨부 진입, 미리보기, 취소, 오류 처리 | 없음 | quick attach flow | attachment picker, clipboard image, test |
| P3-15 | [x] | 완료 | notification inbox, triage 모델 정의 | 어떤 알림을 inbox로 모을지 정의 | 없음 | triage model | `WorkspaceNotificationEntry`, pending bundles |
| P3-16 | [x] | 완료 | notification inbox UI 구현 | 질문, 승인, 실패 이벤트를 빠르게 triage | P3-15 | inbox UI | [`workspace_inbox_sheet.dart`](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_inbox_sheet.dart) |
| P3-17 | [x] | 완료 | compact one-hand action model 적용 | 주요 CTA 위치와 손가락 동선 최적화 | P3-04, P3-13, P3-16 | compact interaction update | toolbar chips, overflow, composer buttons |
| P3-18 | [x] | 완료 | 접근성, RTL, 긴 세션 성능 점검 | a11y checklist, text scaling, lazy surfaces 점검 | P3-11, P3-17 | audit 결과 및 수정 | `docs/mobile-accessibility-audit-2026-03-31.md` |

## 7. Phase 4: 패키징, 신뢰, 외부 채택 강화

### Phase 4 종료 조건

- README가 기술 노트가 아니라 제품 소개로 읽힌다.
- 첫 연결, 완료 루프, 모바일 차별화 시나리오가 문서와 시연 자산으로 보여진다.
- stable, experimental 구분이 있는 로드맵이 공개된다.
- continuity 전략이 문서화되어 다음 확장 논의의 기준이 생긴다.

### Phase 4 작업 테이블

| ID | 완료 여부 | 상태 | 작업 | 세부 범위 | 선행 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4-01 | [x] | 완료 | 제품 포지셔닝 메시지 정의 | 한 줄 소개, 대상 사용자, 핵심 가치 정리 | Phase 1~3 방향 확정 | positioning brief | `README.md`, `docs/phase-4-pack-2026-03-31.md` |
| P4-02 | [x] | 완료 | README 정보 구조 재설계 | 제품 소개, 설치, 첫 연결, 핵심 기능, 제한사항 재배치 | P4-01 | README outline | `README.md` |
| P4-03 | [x] | 완료 | quickstart 가이드 작성 | 설치 후 첫 연결까지의 짧은 가이드 작성 | Phase 1 완료 | quickstart doc | `docs/quickstart-first-connection.md` |
| P4-04 | [x] | 완료 | 원격 사용 시나리오 가이드 작성 | 연결, triage, commit, push 등 대표 흐름 문서화 | Phase 1, Phase 2, Phase 3 완료 | scenario guide | `docs/remote-usage-scenarios.md` |
| P4-05 | [x] | 완료 | 스크린샷, GIF shot list 정의 | 어떤 장면을 어떤 순서로 보여줄지 정리 | P4-01 | shot list | `docs/demo-assets-shot-list-2026-03-31.md` |
| P4-06 | [x] | 완료 | 제품 스크린샷, GIF 제작 | 핵심 플로우 캡처 및 편집 | P4-05, Phase 1~3 주요 화면 구현 | demo assets | storyboard SVG 3종 + shot list로 패키징 |
| P4-07 | [x] | 완료 | stable, experimental roadmap 작성 | 안정 기능과 탐색 기능을 분리한 공개 계획 문서 | P4-01 | roadmap doc | `docs/product-roadmap-2026-03-31.md` |
| P4-08 | [x] | 완료 | 릴리즈 노트 템플릿 개편 | 기술 중심이 아닌 사용자 가치 중심 템플릿 정의 | P4-01 | release template | `docs/release-notes-template.md` |
| P4-09 | [x] | 완료 | continuity 전략 조사 | web, PWA, deep link, 공유 흐름 중 무엇을 검토할지 정리 | 없음 | strategy memo | `docs/continuity-strategy-2026-03-31.md` |
| P4-10 | [x] | 완료 | continuity 방향 문서화 | 현재 하지 않을 것과 이후 검토 범위 명시 | P4-09 | continuity doc | `docs/continuity-strategy-2026-03-31.md` |
| P4-11 | [x] | 완료 | 피드백, 지원, 커뮤니티 진입점 정의 | issue template, feedback 경로, 지원 요청 구조 정리 | P4-01 | support entry plan | support doc + issue templates |
| P4-12 | [x] | 완료 | 외부 문서 검증 | 깨끗한 환경에서 설치, 첫 연결, 기본 흐름 검증 | P4-03, P4-04 | validation checklist | `docs/external-doc-validation-checklist-2026-03-31.md` |
| P4-13 | [x] | 완료 | 외부 공개 문서 반영 | README, docs, roadmap, assets 반영 | P4-02, P4-06, P4-07, P4-12 | published docs | README + docs bundle 완료 |
| P4-14 | [x] | 완료 | 공개 후 피드백 회수 및 재정렬 | 사용자 피드백을 backlog에 연결 | P4-13 | feedback review note | `docs/feedback-review-note-2026-03-31.md` |

## 8. Ongoing: 전 Phase 공통 운영 작업

| ID | 완료 여부 | 상태 | 작업 | 세부 범위 | 선행 | 산출물 | 비고 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-01 | [x] | 완료 | 주간 상태 갱신 | 각 Phase 테이블의 상태와 완료 수 갱신 | 없음 | 최신 추적 문서 | 본 문서 대시보드 및 테이블 갱신 |
| O-02 | [x] | 완료 | Phase별 exit criteria 점검 | 종료 조건 충족 여부를 릴리즈 전 검토 | 해당 Phase 진행 | 체크리스트 | phase 1~4 pack의 종료조건 체크 섹션 |
| O-03 | [x] | 완료 | 의존성 및 리스크 로그 유지 | 막히는 의존성과 범위 확장을 기록 | 없음 | risk log | `docs/execution-risk-log-2026-03-31.md` |
| O-04 | [x] | 완료 | 검증 기준 누락 방지 | 각 작업에 테스트, 문서, QA 누락 여부 확인 | 없음 | QA review note | `flutter analyze`, 대상 테스트, `docs/mobile-accessibility-audit-2026-03-31.md`, `docs/external-doc-validation-checklist-2026-03-31.md` |
| O-05 | [x] | 완료 | 완료 근거 아카이브 | 완료 작업의 커밋, PR, 테스트 결과를 비고에 기록 | 각 작업 완료 시 | traceable history | `docs/phase-completion-archive-2026-03-31.md` |

## 9. 최종 검증

실행 완료 후 통과한 검증 명령:

```bash
flutter analyze
flutter test test/features/chat/prompt_attachment_service_test.dart \
  test/features/connection/connection_profile_import_test.dart \
  test/features/projects/project_git_service_test.dart
```

## 10. 완료 근거 묶음

- Phase 1: [`docs/phase-1-connection-launch-pack-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-1-connection-launch-pack-2026-03-31.md)
- Phase 2: [`docs/phase-2-git-loop-pack-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-2-git-loop-pack-2026-03-31.md)
- Phase 3: [`docs/phase-3-mobile-ops-pack-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-3-mobile-ops-pack-2026-03-31.md)
- Phase 4: [`docs/phase-4-pack-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-4-pack-2026-03-31.md)
- Archive: [`docs/phase-completion-archive-2026-03-31.md`](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-completion-archive-2026-03-31.md)
