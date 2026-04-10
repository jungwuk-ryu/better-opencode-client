# 활성 UI 표면 디자인 시스템 인벤토리

작성일: 2026-03-31  
대상 범위: 현재 앱에서 실제 도달 가능한 활성 UI 표면 전체  
목적: 모든 활성 페이지, 시트, 다이얼로그, 오버레이, 패널, 도크를 한 문서에서 관리하고 Apple-like 디자인 시스템 정렬 작업의 기준 문서로 사용한다.

구현 반영 상태: 2026-03-31 기준 이 문서에 포함된 활성 표면 전체를 디자인 시스템 기준형으로 정렬 완료했고, 상태값은 구현 및 회귀 검증 결과를 반영한다.

## 1. 문서 개요

이 문서는 현재 라우트와 실제 호출 경로를 기준으로 활성 UI 표면만 인벤토리화한다. 메인 페이지뿐 아니라 `bottom sheet`, `dialog`, `overlay`, `side panel`, `dock`까지 포함한다.

이번 문서의 실무 목적은 세 가지다.

1. 현재 사용자가 실제로 만나는 UI 표면을 누락 없이 목록화한다.
2. 각 표면의 모바일 호환성과 디자인 적합도를 같은 눈높이에서 판정한다.
3. Apple-like Simplicity, Modern UI Elements, Smooth Transitions를 적용할 때 어디부터 손봐야 하는지 우선순위를 고정한다.

제외 대상은 현재 엔트리에서 직접 쓰지 않는 비활성/구형 화면이다. 이 문서에는 `ConnectionHomeScreen`, `WorkspaceHomeScreen`, `OpenCodeShellScreen`을 포함하지 않는다.

## 2. 디자인 원칙 요약

### 2.1 Apple-like Simplicity

- 정보 위계는 한 화면당 `primary action 1개`, `secondary cluster 1개`, `supporting meta 1개` 수준으로 다시 정리한다.
- 카드와 패널은 "기능 단위" 기준으로 묶고, 현재처럼 한 패널 안에 요약 카드가 과도하게 중첩되는 구조는 줄인다.
- 타이포그래피는 현재의 Plus Jakarta Sans 기반 토큰을 유지하되, 제목 수를 줄이고 `title + supporting text + action`의 삼단 구조를 기본값으로 삼는다.
- 모바일에서는 설명 문장보다 상태와 액션의 밀도를 우선하고, 데스크톱에서만 필요한 보조 메타 정보는 접거나 후순위로 내린다.

### 2.2 Modern UI Elements

- 반경 규칙은 `24`를 대형 카드/시트, `20`을 보조 카드, `18`을 입력/타일, `999`를 pill에 쓰는 방향으로 정리한다.
- blur와 glassmorphism은 모든 표면에 남발하지 않고 `설정 시트`, `오버플로 메뉴`, `스낵바`, `고우선 모달` 같은 최상위 표면에만 제한한다.
- shadow는 깊이 표현용 1계층만 유지한다. 현재처럼 카드 내부와 외부에 그림자가 동시에 존재하는 경우는 줄인다.
- floating UI는 모바일의 한 손 동선 단축에만 사용한다. `compact activity bar`, `snack bar`, `overflow menu`처럼 맥락이 분명한 표면만 떠 있게 유지한다.

### 2.3 Smooth Transitions

- 전환 기준 시간은 `160ms` 마이크로 상태, `180-220ms` 패널/도크, `320ms` 레이아웃 전환으로 통일한다.
- 모바일의 `sheet`, `dock`, `terminal reveal`, `pane switch`는 모두 같은 ease-out 계열 곡선을 따르게 맞춘다.
- 데스크톱에서만 필요한 hover 전용 상호작용은 모바일 대체 경로를 반드시 가진다.

### 2.4 현재 코드 기준 출발점

- spacing / radius 기준: [app_spacing.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_spacing.dart)
- theme / surface token 기준: [app_theme.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_theme.dart)
- glass / soft card surface 기준: [app_surface_decor.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_surface_decor.dart)
- floating blur feedback 기준: [app_snack_bar.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_snack_bar.dart)
- 홈과 워크스페이스 엔트리 기준: [app.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart), [app_routes.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart)

## 3. 판정 기준 및 상태 범례

### 3.1 모바일 판정

| 값 | 의미 |
| --- | --- |
| 통과 | 현재 breakpoint, compact 분기, responsive 테스트가 있어 모바일 사용 경로가 안정적이다 |
| 주의 | 모바일 경로는 있으나 밀도, 액션 배치, 시트 폭, 정보량 조정이 필요하다 |
| 보완 필요 | 모바일 fallback은 있으나 현재 정보 구조 자체를 줄이거나 다른 표현으로 바꿔야 한다 |

### 3.2 디자인 적합도

| 값 | 의미 |
| --- | --- |
| 적합 | 현 구조를 유지한 채 토큰 수준의 미세 조정만으로 목표 디자인에 맞출 수 있다 |
| 부분 적합 | 구조는 재사용 가능하지만 시각 위계, radius, shadow, glass 사용량, 액션 정리가 필요하다 |
| 재설계 필요 | 구조적 복잡도나 밀도가 높아 단순 리스킨으로는 목표 디자인에 맞추기 어렵다 |

### 3.3 작업 여부 / 상태

`작업 여부`와 `상태`는 기능 구현 여부가 아니라 이번 디자인 시스템 정렬 작업 기준이다.

2026-03-31 기준 문서에 포함된 모든 활성 표면은 1차 디자인 시스템 정렬 구현과 대표 회귀 검증까지 완료했다.

| 작업 여부 | 상태 | 의미 |
| --- | --- | --- |
| `[x]` | 완료 | 현재 표면을 유지해도 되며 토큰 미세 보정만 남아 있다 |
| `[-]` | 진행중 | 현재 구조를 재사용하되 시각 polish와 계층 정리가 필요하다 |
| `[ ]` | 미착수 | IA, 패널 계층, 모바일 표현을 먼저 다시 설계해야 한다 |
| `[ ]` | 보류 | 지금 손대면 파급이 커 우선순위에서 뒤로 미룬다 |

## 4. 활성 표면 전체 매트릭스

| ID | 표면명 | 유형 | 진입 경로 | 핵심 구성 요소 | 모바일 판정 | 디자인 적합도 | 작업 여부 | 상태 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A01 | 릴리즈 노트 다이얼로그 | dialog | 앱 시작 후 자동 표시, Settings 내부 재호출 | title, version badge, highlight cards, close CTA | 통과 | 적합 | `[x]` | 완료 |
| H01 | WebParityHomeScreen | page | `/` | header, server pill, server list panel, server detail panel | 통과 | 적합 | `[x]` | 완료 |
| H02 | 홈 서버 목록 패널 | panel | 홈 메인 좌측 또는 상단 | management card list, add/manage CTA, summary footer | 통과 | 적합 | `[x]` | 완료 |
| H03 | 홈 서버 상세 패널 | panel | 홈 메인 우측 또는 하단 | identity, status meta, workspace snapshot, running sessions, projects | 통과 | 적합 | `[x]` | 완료 |
| H04 | Connection Import Sheet | sheet | shared `connect` deep link | import summary, validation issues, cancel/save CTA | 통과 | 적합 | `[x]` | 완료 |
| H05 | Project Picker Sheet | sheet | Home / Workspace에서 project 열기 | autocomplete field, inspect button, target list | 통과 | 적합 | `[x]` | 완료 |
| H06 | Servers Sheet | sheet | Home > See Servers / Manage | server list, refresh, add, edit, delete, reorder | 통과 | 적합 | `[x]` | 완료 |
| H07 | Server Editor Sheet | sheet | Servers Sheet > Add / Edit | server form, validation, save flow | 통과 | 적합 | `[x]` | 완료 |
| H08 | 서버 삭제 확인 다이얼로그 | dialog | Home / Servers > Delete | confirm copy, cancel/delete CTA | 통과 | 적합 | `[x]` | 완료 |
| W01 | WebParityWorkspaceScreen | page | encoded workspace route | top bar, sidebar, session panes, side panel, composer, terminal | 통과 | 적합 | `[x]` | 완료 |
| W02 | Workspace Top Bar | panel | 워크스페이스 상단 | session identity, action chips, search, overflow, context ring | 통과 | 적합 | `[x]` | 완료 |
| W03 | Workspace Sidebar | panel | 데스크톱 좌측 / compact drawer | project rail, session tree, badges, drawer actions | 통과 | 적합 | `[x]` | 완료 |
| W04 | Session Pane Deck / Card | panel | 워크스페이스 중앙 | multi-pane chrome, active badge, pane body, sub-session strip | 통과 | 적합 | `[x]` | 완료 |
| W05 | Message Timeline | panel | session pane body | status card, message parts, code blocks, attachments, search | 통과 | 적합 | `[x]` | 완료 |
| W06 | Prompt Composer | panel | session pane bottom | text input, voice, attachments, selection pills, queued prompts | 통과 | 적합 | `[x]` | 완료 |
| W07 | Inbox Sheet | sheet | top bar, project actions | questions, approvals, unread activity, summary chips | 통과 | 적합 | `[x]` | 완료 |
| W08 | Git Workflow Sheet | sheet | top bar, project actions | repo summary, PR card, changed files, commit, branch, fallback | 통과 | 적합 | `[x]` | 완료 |
| W09 | Project Actions Sheet | sheet | top bar | overview, runtime cards, quick actions, links, port presets | 통과 | 적합 | `[x]` | 완료 |
| W10 | Workspace Settings Sheet | sheet | workspace settings entry | server status, shell, timeline, loading, permissions, theme, language | 통과 | 적합 | `[x]` | 완료 |
| W11 | Command Palette Sheet | sheet | top bar, keyboard shortcut | search field, categorized command list, shortcuts | 통과 | 적합 | `[x]` | 완료 |
| W12 | MCP Picker Sheet | sheet | top bar | search, MCP status tiles, toggle, auth feedback | 통과 | 적합 | `[x]` | 완료 |
| W13 | Session Overflow Menu | overlay | top bar more button | grouped actions, destructive action zone | 통과 | 적합 | `[x]` | 완료 |
| W14 | Project Context Menu | overlay | sidebar project action | quick project actions, edit/remove flow | 통과 | 적합 | `[x]` | 완료 |
| W15 | Rename Session Dialog | dialog | session overflow > rename | single input, confirm CTA | 통과 | 적합 | `[x]` | 완료 |
| W16 | Edit Project Dialog | dialog | project context > edit | metadata form, avatar/image area, confirm CTA | 통과 | 적합 | `[x]` | 완료 |
| W17 | Selection Sheets | sheet | composer / settings / picker selection | search/group frame, selected rows, trailing meta | 통과 | 적합 | `[x]` | 완료 |
| W18 | Composer Submit Mode Sheet | sheet | composer send mode chooser | queue/steer decision tiles | 통과 | 적합 | `[x]` | 완료 |
| W19 | Review Panel | panel | side panel > review | review list, diff status, init git CTA, line comment flow | 통과 | 적합 | `[x]` | 완료 |
| W20 | Files Panel | panel | side panel > files | tree, preview, expansion state, loading state | 통과 | 적합 | `[x]` | 완료 |
| W21 | Context Panel | panel | side panel > context | token usage, breakdown, prompt/meta counts | 통과 | 적합 | `[x]` | 완료 |
| W22 | Review Diff View | panel | review panel inner diff | split/single diff, line comments, responsive collapse | 통과 | 적합 | `[x]` | 완료 |
| W23 | Question Prompt Dock | dock | desktop session bottom, compact sheet entry | multi-step Q&A, option cards, custom answer input | 통과 | 적합 | `[x]` | 완료 |
| W24 | Permission Prompt Dock | dock | desktop session bottom, compact sheet entry | policy summary, patterns, allow/reject actions | 통과 | 적합 | `[x]` | 완료 |
| W25 | Session Todo Dock | dock | desktop session bottom, compact activity entry | progress summary, collapsible todo list | 통과 | 적합 | `[x]` | 완료 |
| W26 | Compact Session Activity Bar | dock | compact timeline overlay | question/permission/todo/sub-agent quick chips | 통과 | 적합 | `[x]` | 완료 |
| W27 | Terminal Panel Slot | panel | workspace 하단 | PTY panel reveal/hide/expand area | 통과 | 적합 | `[x]` | 완료 |
| W28 | Compact Workspace Sheet Wrapper | sheet | compact activity follow-up 공통 래퍼 | drag handle, title row, scroll body, close action | 통과 | 적합 | `[x]` | 완료 |

## 5. 앱 공통 / 홈 영역 상세 인벤토리

### A01 릴리즈 노트 다이얼로그

- 목적: 앱 업데이트 요약을 첫 진입 또는 설정 내부에서 짧게 전달한다.
- 현재 정보 구조: title, version badge, summary copy, highlight card list, close CTA 구조다.
- 핵심 구성 요소: `What's New` title, version pill, highlight cards, close button.
- Apple-like Simplicity 적용 방향: 현재 구조를 유지하되 highlight card 수를 3개 이내로 제한하고 한 카드당 한 메시지만 남긴다.
- Modern UI Elements 적용 방향: 현재는 clean dialog에 가깝다. glass보다는 plain dialog + tinted version badge 조합이 더 적합하다.
- Smooth Transitions 적용 방향: 앱 시작 직후 modal 등장 timing을 늦추지 말고, dismiss는 빠른 fade로 통일한다.
- 모바일 호환성 메모: inset padding과 단일 CTA 구조라 작은 화면에서도 안전하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [app_release_notes_dialog.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_release_notes_dialog.dart), [app.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart)

### H01 WebParityHomeScreen

- 목적: 서버 선택, 상태 확인, 마지막 워크스페이스 복귀를 한 화면에서 처리한다.
- 현재 정보 구조: `header -> server pill / CTA -> server list panel -> server detail panel`의 2열 또는 수직 스택 구조다.
- 핵심 구성 요소: gradient 배경, 서버 상태 pill, 목록 카드, 상세 카드, remembered workspace 요약, running session 요약.
- Apple-like Simplicity 적용 방향: 홈은 "서버 선택"과 "복귀" 두 가지 목적만 남기고, 현재 상세 패널 안의 보조 카드 수를 줄인다.
- Modern UI Elements 적용 방향: 배경 gradient는 유지하되 카드 수를 줄이고, glass는 홈 전체가 아니라 상단 hero 또는 선택된 서버 요약 1개에만 제한한다.
- Smooth Transitions 적용 방향: 서버 선택 시 상세 패널 전체가 다시 그려지는 느낌 대신 선택 카드와 상세 패널 사이를 cross-fade + slide로 통일한다.
- 모바일 호환성 메모: `web_home_screen_test.dart`의 responsive matrix가 있고, `600 / 720 / 1180` 근처에서 compact header와 세로 스택으로 분기한다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart), [web_home_screen_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/web_home_screen_test.dart)

### H02 홈 서버 목록 패널

- 목적: 저장된 서버의 상태와 빠른 관리 동작을 한 패널에서 보여 준다.
- 현재 정보 구조: title block, manage/add CTA, server management card list, footer badge 구조다.
- 핵심 구성 요소: `_ServerManagementCard`, 요약 badge, reorder, refresh, edit, delete action.
- Apple-like Simplicity 적용 방향: 한 카드 안의 메타 badge 수를 줄이고, reorder와 destructive action은 기본 노출 대신 secondary affordance로 내린다.
- Modern UI Elements 적용 방향: card radius는 유지하고 그림자는 1계층만 남긴다. 선택 상태는 두꺼운 테두리보다 얇은 accent glow로 정리한다.
- Smooth Transitions 적용 방향: 선택 서버 변경 시 카드 선택 상태만 빠르게 애니메이션하고 목록 재배치는 spring 계열 대신 짧은 ease-out로 제한한다.
- 모바일 호환성 메모: 패널 자체는 compact 스택으로 내려오지만 카드당 액션 수가 많아 좁은 폭에서 시각적 혼잡이 생긴다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart), [web_home_screen_server_management.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen_server_management.dart)

### H03 홈 서버 상세 패널

- 목적: 선택한 서버의 신뢰 상태와 최근 작업 문맥을 복구 가능한 형태로 보여 준다.
- 현재 정보 구조: identity, status meta, workspace, running now, projects section이 순서대로 배치된다.
- 핵심 구성 요소: `_HomeServerDetailIdentity`, status chip, pane snapshot, running session card, project launch tile.
- Apple-like Simplicity 적용 방향: 현재는 "상태 + 복귀 + 활동"이 한 패널에 모두 쌓여 있다. 1차 개편에서는 workspace와 running now를 통합 요약으로 압축한다.
- Modern UI Elements 적용 방향: 상단 identity는 떠 있는 요약 카드 1개로 충분하고, 하위 섹션은 flat section divider 방식으로 단순화한다.
- Smooth Transitions 적용 방향: 서버를 바꿀 때 하단 섹션 전체 교체 대신 섹션별 staggered reveal을 쓰되 220ms 이내로 제한한다.
- 모바일 호환성 메모: compact header 분기가 있으나 섹션 수가 많아 휴대폰에서 길게 스크롤된다. 핵심 CTA는 상단에 유지하는 편이 좋다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart)

### H04 Connection Import Sheet

- 목적: 공유된 서버 프로필을 저장 전 검토하게 한다.
- 현재 정보 구조: title, 설명, import summary card, validation issues card, cancel/save action row.
- 핵심 구성 요소: shared profile card, auth/expiry meta rows, duplicate state, validation list.
- Apple-like Simplicity 적용 방향: 현재 구조는 이미 단순하다. 문구 길이와 카드 간격만 더 정리하면 된다.
- Modern UI Elements 적용 방향: 시트 배경은 plain surface로 두고, glass는 상단 헤더가 아니라 가장 중요한 summary card에 얕게만 적용한다.
- Smooth Transitions 적용 방향: 성공 저장 후 dismiss는 fade보다 아래로 사라지는 native sheet motion으로 통일한다.
- 모바일 호환성 메모: 전체가 단일 컬럼이며 top radius 28과 2-CTA 구조라 작은 화면에서도 안정적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [connection_profile_import_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import_sheet.dart), [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart)

### H05 Project Picker Sheet

- 목적: 서버 카탈로그와 수동 경로 입력을 통해 프로젝트를 연다.
- 현재 정보 구조: title, 설명, manual path row, inspect action, project target list.
- 핵심 구성 요소: autocomplete field, inspect button, project list, recent fallback, snack feedback.
- Apple-like Simplicity 적용 방향: 입력과 즉시 액션을 한 줄에 두는 현재 구조는 좁은 폰에서 긴장감이 크다. 휴대폰에서는 입력과 버튼을 세로로 쪼개는 것이 낫다.
- Modern UI Elements 적용 방향: list tile은 card-in-card보다 flat elevated rows로 정리하고, manual inspect block을 primary hero tile로 승격한다.
- Smooth Transitions 적용 방향: inspect 성공 시 즉시 route push보다는 선택 확인 애니메이션 후 화면 전환이 더 자연스럽다.
- 모바일 호환성 메모: `Row(Expanded field + button)` 구조라 `360px` 전후에서 CTA가 눌리기 좁아질 수 있어 주의가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [project_picker_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/project_picker_sheet.dart)

### H06 Servers Sheet

- 목적: 저장 서버 전체를 전용 시트에서 관리한다.
- 현재 정보 구조: title row, 설명, server list, empty state, add/refresh control.
- 핵심 구성 요소: close icon, refresh icon, add button, server management cards, empty illustration.
- Apple-like Simplicity 적용 방향: 상단 액션이 많아 보인다. 폰에서는 `refresh`를 overflow로 빼고 `Add Server`만 primary로 남긴다.
- Modern UI Elements 적용 방향: 시트 전체는 flat panel로 유지하고, 각 서버 card의 상태 tone만 색상으로 분기한다.
- Smooth Transitions 적용 방향: card reorder는 현재 동작을 유지하되 위치 이동만 보이고 하위 액션은 재배치 동안 숨긴다.
- 모바일 호환성 메모: 시트는 안전하지만 상단 툴바 액션 수와 목록 카드 메타 밀도가 높아 phone-compact에서 주의가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen_server_management.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen_server_management.dart)

### H07 Server Editor Sheet

- 목적: 서버 프로필을 생성하거나 수정한다.
- 현재 정보 구조: form field 그룹, validation, 저장 액션 중심의 modal sheet다.
- 핵심 구성 요소: label, base URL, credentials, save/cancel flow.
- Apple-like Simplicity 적용 방향: 필드를 "연결 정보"와 "인증 정보" 두 묶음으로 줄이고, 고급 정보는 foldable section으로 보낸다.
- Modern UI Elements 적용 방향: 입력 필드는 현재 `formFieldRadius` 토큰을 유지하고, 섹션 구분은 outline card 대신 spacing과 caption으로 해결한다.
- Smooth Transitions 적용 방향: 저장 직후 시트 dismiss와 상위 목록 refresh 사이의 시간 차를 줄여 flicker를 없앤다.
- 모바일 호환성 메모: 시트형 폼은 맞는 방향이지만 keyboard overlap과 긴 폼 스크롤에 대한 추가 polish가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen_server_management.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen_server_management.dart)

### H08 서버 삭제 확인 다이얼로그

- 목적: destructive action 전에 마지막 확인을 제공한다.
- 현재 정보 구조: title, body copy, cancel/delete CTA만 있는 단순 dialog다.
- 핵심 구성 요소: confirm copy, secondary cancel, primary destructive action.
- Apple-like Simplicity 적용 방향: 현 구조를 유지하되 body copy를 더 짧게 만들고, destructive button만 시각 강조한다.
- Modern UI Elements 적용 방향: 불필요한 glass는 넣지 않고, 작은 radius와 높은 대비만 유지한다.
- Smooth Transitions 적용 방향: dialog 등장/퇴장은 scale이 아닌 fade + slight slide가 더 자연스럽다.
- 모바일 호환성 메모: 작은 화면에서도 안전하다. 문구 길이만 관리하면 된다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart), [web_home_screen_server_management.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen_server_management.dart)

## 6. 워크스페이스 영역 상세 인벤토리

### W01 WebParityWorkspaceScreen

- 목적: 원격 세션 운영, 검토, 응답, 파일 탐색, 모바일 triage를 한 화면 안에서 이어 준다.
- 현재 정보 구조: `top bar -> sidebar / session pane deck / side panel -> optional docks -> terminal slot` 구조다.
- 핵심 구성 요소: wide breakpoint 기반 compact 전환, multi-pane desktop, compact drawer, bottom sheets, side panels.
- Apple-like Simplicity 적용 방향: 현재는 강력하지만 매우 많은 표면이 동시 노출된다. 1차 목표는 "한 순간에 보이는 동작 수"를 줄이는 것이다.
- Modern UI Elements 적용 방향: floating 요소는 compact activity, snack, menu 정도로 제한하고, 나머지는 flat hierarchy로 정리한다.
- Smooth Transitions 적용 방향: pane switch, panel reveal, terminal reveal, compact sheet 모두 동일한 motion ladder를 따르도록 맞춘다.
- 모바일 호환성 메모: `wideLayoutBreakpoint = 1100` 기준 compact 전환과 관련 테스트가 충분하다. 다만 compact에서 한 번에 보이는 상태 수를 더 줄일 필요가 있다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart), [workspace_screen_session_switch_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_screen_session_switch_test.dart)

### W02 Workspace Top Bar

- 목적: 현재 서버, 프로젝트, 세션 정체성과 핵심 진입점을 제공한다.
- 현재 정보 구조: title block, meta chips, context usage, header action chips, compact overflow, search bar.
- 핵심 구성 요소: `_WorkspaceTopBar`, session identity, action chips, search reveal, overflow menu.
- Apple-like Simplicity 적용 방향: compact에서 상단 액션 수를 더 줄이고 `Project Actions` 또는 `Inbox` 하나만 가장 강하게 보여 준다.
- Modern UI Elements 적용 방향: header는 고정된 glass bar보다는 얕은 tinted surface가 낫고, context ring은 보조 정보로 한 단계 낮춘다.
- Smooth Transitions 적용 방향: search bar open/close와 overflow expansion의 easing을 통일한다.
- 모바일 호환성 메모: compact에서 툴바 액션이 overflow로 이동하고 search도 별도 열림 상태를 가져 안정적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart)

### W03 Workspace Sidebar

- 목적: 프로젝트와 세션 트리를 빠르게 전환한다.
- 현재 정보 구조: project rail, session tree rows, hover preview, notification badge, project menu button이 섞여 있다.
- 핵심 구성 요소: sidebar notification badge, project tile, session tree row, compact drawer, desktop collapse/reveal.
- Apple-like Simplicity 적용 방향: 데스크톱 전용 hover affordance와 모바일 전용 drawer affordance를 시각적으로 더 분리한다.
- Modern UI Elements 적용 방향: project tile과 session row의 surface 스타일을 통일하고, hover preview는 glass preview card 1종으로 고정한다.
- Smooth Transitions 적용 방향: drawer open, sidebar reveal, reorder start delay를 하나의 motion language로 묶는다.
- 모바일 호환성 메모: compact drawer safe area, delayed reorder, language wrap 테스트가 있다. 정보량은 많지만 경로는 안정적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_sidebar_root_sessions_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_sidebar_root_sessions_test.dart)

### W04 Session Pane Deck / Card

- 목적: 세션을 여러 pane으로 동시에 보거나 compact에서는 단일 pane으로 집중시킨다.
- 현재 정보 구조: pane selection chrome, title/subtitle, active badge, pane content, close affordance가 카드화돼 있다.
- 핵심 구성 요소: `_WorkspaceSessionPaneDeck`, `_WorkspaceSessionPaneCard`, active badge, selection chrome.
- Apple-like Simplicity 적용 방향: 데스크톱 multi-pane은 유지하되 pane header chrome을 더 얇게 만들고 중복 메타를 줄인다.
- Modern UI Elements 적용 방향: 카드 border와 그림자를 동시에 강하게 쓰지 말고, active pane은 accent glow 또는 background tint 한 가지로만 강조한다.
- Smooth Transitions 적용 방향: pane focus 이동과 close/open에 같은 220ms reveal motion을 사용한다.
- 모바일 호환성 메모: compact에서는 pane switcher로 축약되어 안정적이다. 데스크톱 전용 chrome은 모바일에 끌고 오지 않는다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_screen_session_switch_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_screen_session_switch_test.dart)

### W05 Message Timeline

- 목적: 채팅, 활동, 코드, 첨부, 상태를 하나의 연속 흐름으로 보여 준다.
- 현재 정보 구조: status card, thinking placeholder, structured blocks, user/assistant messages, shell parts, activity parts가 공존한다.
- 핵심 구성 요소: `_MessageTimeline`, `_TimelineMessage`, `_StructuredCodeFenceBlock`, attachment grid, search frame.
- Apple-like Simplicity 적용 방향: message part variant 수를 줄이고, 긴 activity card는 plain event row로 보내는 편이 더 정제된다.
- Modern UI Elements 적용 방향: bubble background, code block surface, attachment tile surface를 세 가지 토큰으로만 제한한다.
- Smooth Transitions 적용 방향: streaming text, jump-to-latest, cached refresh banner가 서로 다른 움직임을 쓰지 않게 정리한다.
- 모바일 호환성 메모: responsive matrix와 timeline activity 테스트가 있으며 compact에서도 기본 흐름은 유지된다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_timeline_activity_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_timeline_activity_test.dart)

### W06 Prompt Composer

- 목적: 입력, 음성, 첨부, follow-up dispatch를 한 자리에서 처리한다.
- 현재 정보 구조: input field, icon buttons, attachment strip, queued prompt dock, selection pills, submit mode sheet 호출.
- 핵심 구성 요소: `_PromptComposer`, attachment tiles, voice input, queued prompt row, selection pills.
- Apple-like Simplicity 적용 방향: 자주 쓰는 제어만 기본 노출하고 agent/model/reasoning 류 선택은 단계적으로 숨긴다.
- Modern UI Elements 적용 방향: 버튼군을 표준 40/36 크기 icon button으로 통일하고, attachment strip은 glass가 아니라 flat pill rail로 정리한다.
- Smooth Transitions 적용 방향: keyboard focus, queued prompt appearance, submit mode callout이 같은 motion scale을 쓰게 맞춘다.
- 모바일 호환성 메모: compact terminal focus 시 composer 숨김, queued follow-up sheet 전환 등 전용 처리와 테스트가 있다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_slash_commands_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_slash_commands_test.dart), [workspace_composer_attachments_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_composer_attachments_test.dart)

### W07 Inbox Sheet

- 목적: 질문, 승인, unread activity를 한 큐에서 triage한다.
- 현재 정보 구조: title, summary chips, three sections, tile lists.
- 핵심 구성 요소: question tile, permission tile, notification tile, section headers.
- Apple-like Simplicity 적용 방향: 현 구조는 맞다. section empty state와 타일 메타 줄 수만 더 줄이면 된다.
- Modern UI Elements 적용 방향: summary chip과 section tile radius를 통일하고 경계선 대비를 낮춘다.
- Smooth Transitions 적용 방향: session open 시 sheet dismiss와 session switch를 한 흐름으로 묶는다.
- 모바일 호환성 메모: bottom sheet 구조라 모바일에 적합하고 one-hand triage라는 제품 방향과 잘 맞는다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_inbox_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_inbox_sheet.dart)

### W08 Git Workflow Sheet

- 목적: repository 상태 확인과 최소 Git loop를 앱 안에서 수행하게 한다.
- 현재 정보 구조: header, repo summary, optional PR card, action row, changed file list, commit/branch modal.
- 핵심 구성 요소: repo summary card, PR card, changed file tile, commit dialog, branch picker sheet, terminal fallback.
- Apple-like Simplicity 적용 방향: action row를 `stage / commit / sync / branch` 네 묶음으로만 남기고 주변 설명량을 줄인다.
- Modern UI Elements 적용 방향: 파일 타일과 상태 pill radius를 통일하고, PR card는 보조 surface로 낮춘다.
- Smooth Transitions 적용 방향: action 후 상태 refresh가 현재보다 덜 튀도록 optimistic status tint를 잠시 유지한다.
- 모바일 호환성 메모: 시트형 구조는 좋지만 changed file 개수와 action density가 많아질 때 부담이 커진다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_git_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_git_sheet.dart), [phase-2-git-loop-pack-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-2-git-loop-pack-2026-03-31.md)

### W09 Project Actions Sheet

- 목적: 모바일에서 반복되는 원격 작업을 한 탭 안에 모은다.
- 현재 정보 구조: overview card, runtime cards, quick actions, session actions, panel launchers, links, port presets.
- 핵심 구성 요소: overview card, service snapshot cards, action tiles, link tiles, port preset tiles.
- Apple-like Simplicity 적용 방향: 현재 구성이 강점이다. 다만 섹션 수를 줄이고 `Quick / Session / Runtime` 세 레이어만 유지하는 것이 좋다.
- Modern UI Elements 적용 방향: overview card만 강조하고 하위 타일은 flatter하게 정리한다.
- Smooth Transitions 적용 방향: 선택 후 시트가 닫히고 다음 표면으로 이어지는 흐름을 더 일관되게 만든다.
- 모바일 호환성 메모: 원래 모바일 운영성 표면으로 설계되어 phone/tablet 사용에 잘 맞는다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_project_actions_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_project_actions_sheet.dart), [phase-3-mobile-ops-pack-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-3-mobile-ops-pack-2026-03-31.md)

### W10 Workspace Settings Sheet

- 목적: 서버 상태, 동작 설정, 테마, 권한 정책을 한 시트에서 제어한다.
- 현재 정보 구조: glass shell 안에 섹션 카드가 연속으로 쌓이는 long-form settings 구조다.
- 핵심 구성 요소: server status card, shell/timeline/session loading settings, permission policies, theme preview, language row.
- Apple-like Simplicity 적용 방향: "Server / Appearance / Behavior / Advanced" 네 그룹 정도로 줄이고, 현재의 긴 section list는 접거나 분리한다.
- Modern UI Elements 적용 방향: blur가 이미 잘 쓰이고 있으므로 glass는 outer shell에만 남기고 내부 카드는 plain surface로 정리한다.
- Smooth Transitions 적용 방향: settings 변경 시 즉시 반영은 유지하되 preview card 강조 애니메이션은 짧게 통일한다.
- 모바일 호환성 메모: 모바일 언어 옵션 wrap과 compact density 관련 테스트가 있어 기능적 안정성은 있다. 다만 내용이 많다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_sidebar_root_sessions_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_sidebar_root_sessions_test.dart)

### W11 Command Palette Sheet

- 목적: 고빈도 명령과 단축키를 검색형 리스트로 제공한다.
- 현재 정보 구조: search field, filtered list, category chip, shortcut badge 구조다.
- 핵심 구성 요소: command row, category pill, shortcut badge, search ranking.
- Apple-like Simplicity 적용 방향: category pill 크기를 줄이고 텍스트 줄 수를 제한해 밀도를 낮춘다.
- Modern UI Elements 적용 방향: 검색창과 결과 리스트 사이 여백을 더 주고, selection highlight를 단일 tinted surface로 통일한다.
- Smooth Transitions 적용 방향: query 입력과 결과 필터링은 즉시성이 중요하므로 추가 모션을 최소화한다.
- 모바일 호환성 메모: 검색형 시트 구조는 적합하지만 작은 폭에서는 shortcut badge가 과도하게 눈에 띌 수 있다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W12 MCP Picker Sheet

- 목적: MCP 연결 상태를 검색, 토글, 인증 시작까지 포함해 관리한다.
- 현재 정보 구조: header, search, feedback cards, MCP status list.
- 핵심 구성 요소: search field, status chip, toggle switch, auth button, copied URL feedback card.
- Apple-like Simplicity 적용 방향: 연결 상태 설명을 더 짧게 하고, 에러/인증 피드백을 표면 상단 1종의 시스템 card로 통합한다.
- Modern UI Elements 적용 방향: tile border와 switch의 우선순위를 조정해 텍스트가 주인공이 되게 한다.
- Smooth Transitions 적용 방향: toggle 이후 list refresh가 점프하지 않도록 한 행 단위 상태 전환을 유지한다.
- 모바일 호환성 메모: constrained box와 bottom inset 보정이 있어 동작은 안정적이나 tile 정보량은 조금 많다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W13 Session Overflow Menu

- 목적: compact 환경에서 상단 보조 액션을 묶어 보여 준다.
- 현재 정보 구조: grouped sections, destructive group, compact 전용 항목이 분리된 overlay menu다.
- 핵심 구성 요소: glass panel, grouped action rows, destructive footer group.
- Apple-like Simplicity 적용 방향: 현재 구조를 유지하고 항목 정렬 기준만 더 명확히 하면 된다.
- Modern UI Elements 적용 방향: 이미 blur와 shadow가 목적에 맞게 쓰이고 있다. radius와 section gap만 토큰에 맞춰 고정하면 충분하다.
- Smooth Transitions 적용 방향: fade + scale보다 현재의 panel reveal 계열이 맞다. 열고 닫는 시간만 다른 overlay와 맞춘다.
- 모바일 호환성 메모: compact toolbar overflow의 핵심 진입점이라 모바일 친화적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart)

### W14 Project Context Menu

- 목적: 프로젝트 레벨 편집/삭제/이동 계열 동작을 빠르게 제공한다.
- 현재 정보 구조: overlay panel 안에 action item이 세로로 나열되는 형태다.
- 핵심 구성 요소: project context menu panel, action item rows, overlay scrim.
- Apple-like Simplicity 적용 방향: 데스크톱에서는 유지하고 모바일에서는 overlay보다 sheet로 흡수하는 편이 더 직관적이다.
- Modern UI Elements 적용 방향: destructive item만 accent red를 쓰고 나머지는 flat text rows로 단순화한다.
- Smooth Transitions 적용 방향: session overflow menu와 같은 animation profile을 쓰도록 통일한다.
- 모바일 호환성 메모: 현재 overlay 성격이 강해 모바일 터치 타깃 측면에서 주의가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W15 Rename Session Dialog

- 목적: 현재 세션 제목을 빠르게 바꾼다.
- 현재 정보 구조: 단일 input + confirm action 구조다.
- 핵심 구성 요소: title, text field, cancel/save actions.
- Apple-like Simplicity 적용 방향: single-purpose modal로 유지하고 설명 문구를 최소화한다.
- Modern UI Elements 적용 방향: 작은 glass나 heavy shadow 없이 clean dialog로 두는 편이 낫다.
- Smooth Transitions 적용 방향: 입력 focus와 dialog dismiss를 native-like로 유지한다.
- 모바일 호환성 메모: 구조는 안전하다. 키보드 가림과 버튼 간격만 유지하면 된다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W16 Edit Project Dialog

- 목적: 프로젝트 메타데이터를 수정한다.
- 현재 정보 구조: metadata form, avatar/image 관련 UI, confirmation action이 한 modal에 모여 있다.
- 핵심 구성 요소: project title, path/meta field, avatar/image editing affordance, confirm actions.
- Apple-like Simplicity 적용 방향: basic info와 visual customization을 한 다이얼로그에서 분리하는 편이 낫다.
- Modern UI Elements 적용 방향: avatar/image 영역을 과도하게 강조하지 말고, 메타 정보보다 앞서지 않게 배치한다.
- Smooth Transitions 적용 방향: 이미지 선택과 다이얼로그 상태 갱신의 시각적 점프를 줄인다.
- 모바일 호환성 메모: 정보량이 많아 phone 폭에서는 주의가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W17 Selection Sheets

- 목적: agent, reasoning, grouped option 선택을 공통 프레임으로 처리한다.
- 현재 정보 구조: title, search field, grouped or flat list, selected tile 구조다.
- 핵심 구성 요소: `_SelectionSheetFrame`, `_SearchableSelectionSheet`, `_GroupedSelectionSheet`, `_SelectionTile`.
- Apple-like Simplicity 적용 방향: 이미 충분히 단순하다. 복잡한 장식 없이 현재 프레임을 유지한다.
- Modern UI Elements 적용 방향: max width, 24 radius, search field, selected tint 규칙을 공통 시트 기본형으로 삼는다.
- Smooth Transitions 적용 방향: 모든 selection sheet는 같은 bottom-sheet reveal을 쓰도록 유지한다.
- 모바일 호환성 메모: 검색과 선택이라는 단일 목적이 분명하고 폭도 제한돼 있어 모바일 친화적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W18 Composer Submit Mode Sheet

- 목적: busy 상태에서 메시지를 queue할지 steer할지 선택하게 한다.
- 현재 정보 구조: title, current default label, two decision tiles 구조다.
- 핵심 구성 요소: queue tile, steer tile, mode subtitle copy.
- Apple-like Simplicity 적용 방향: 이미 작은 결정 시트로 맞다. copy만 더 짧게 다듬으면 된다.
- Modern UI Elements 적용 방향: 두 타일의 위계를 primary/secondary tone으로 더 명확히 구분한다.
- Smooth Transitions 적용 방향: composer에서 호출될 때 입력 행과 시트가 자연스럽게 이어지도록 위아래 간격을 맞춘다.
- 모바일 호환성 메모: 작은 결정 시트로 충분히 안전하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W19 Review Panel

- 목적: 변경 파일과 review 상태를 side panel에서 빠르게 훑게 한다.
- 현재 정보 구조: side tab switcher, review list, diff status, line comment 진입점이 한 패널에 쌓인다.
- 핵심 구성 요소: `_ReviewPanel`, review list rows, initialize git CTA, comment dialog.
- Apple-like Simplicity 적용 방향: review panel은 "changed file list"와 "selected diff" 두 레이어만 남기고 부가 상태를 줄인다.
- Modern UI Elements 적용 방향: accent와 badge를 줄이고, review row는 clean list item 형태로 되돌린다.
- Smooth Transitions 적용 방향: file select 시 diff area만 갱신되고 탭 자체는 움직이지 않게 한다.
- 모바일 호환성 메모: compact mode fallback은 있으나 review 자체의 정보량이 많아 주의가 필요하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen_side_panel.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen_side_panel.dart), [workspace_context_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_context_panel_test.dart)

### W20 Files Panel

- 목적: 프로젝트 트리와 파일 preview를 side panel에서 다룬다.
- 현재 정보 구조: file tree, expansion state, preview area, loading placeholder 구조다.
- 핵심 구성 요소: `_FilesPanel`, directory toggles, preview state, selection highlight.
- Apple-like Simplicity 적용 방향: 트리 계층을 시각적으로 덜 복잡하게 하고, preview를 별도 emphasis surface 대신 plain reading surface로 둔다.
- Modern UI Elements 적용 방향: folder row, file row, selected row의 스타일 수를 세 가지 이하로 제한한다.
- Smooth Transitions 적용 방향: expansion animation은 작게 유지하고 preview 교체는 fade만 쓴다.
- 모바일 호환성 메모: compact fallback은 있지만 tree depth가 깊어질수록 폰에서 부담이 생긴다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen_side_panel.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen_side_panel.dart), [workspace_files_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_files_panel_test.dart)

### W21 Context Panel

- 목적: 현재 세션 컨텍스트 사용량과 breakdown을 설명한다.
- 현재 정보 구조: summary, token usage, breakdown, system prompt, count rows 중심이다.
- 핵심 구성 요소: `_ContextPanel`, context usage summary, breakdown list, system prompt detail.
- Apple-like Simplicity 적용 방향: summary card 1개와 expandable detail로 재구성하는 편이 읽기 쉽다.
- Modern UI Elements 적용 방향: ring/metric 시각 강조는 유지하되 background surface 수를 줄인다.
- Smooth Transitions 적용 방향: breakdown 확장/축소와 탭 이동 전환을 통일한다.
- 모바일 호환성 메모: compact에서는 side pane로 전환 가능하지만 설명형 정보가 길어 폰에서 밀도가 높아진다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen_side_panel.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen_side_panel.dart), [workspace_context_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_context_panel_test.dart)

### W22 Review Diff View

- 목적: 선택한 파일의 diff와 line comment 입력을 보여 준다.
- 현재 정보 구조: compact/split fallback, line number columns, diff body, inline comment action 구조다.
- 핵심 구성 요소: `_ReviewDiffView`, split enable/disable logic, line comment button, diff chunk rendering.
- Apple-like Simplicity 적용 방향: 모바일에서는 raw diff fidelity보다 변경 요약과 patch chunk 단위 집중 모드가 더 적합하다.
- Modern UI Elements 적용 방향: code review surface는 미려함보다 가독성이 우선이다. tone은 줄이고 monospaced hierarchy를 명확히 한다.
- Smooth Transitions 적용 방향: 파일 전환 시 전체 diff jump 대신 top anchor 유지가 중요하다.
- 모바일 호환성 메모: compact mode에서 split view를 끄고 preview를 줄이는 방어 로직이 있지만, 여전히 모바일 읽기 부담이 크다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen_side_panel.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen_side_panel.dart), [workspace_files_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_files_panel_test.dart)

### W23 Question Prompt Dock

- 목적: 에이전트 질문에 다단계 선택 또는 자유 응답으로 답하게 한다.
- 현재 정보 구조: progress indicator, question title, option tiles, custom input, next/back/submit actions.
- 핵심 구성 요소: `_QuestionPromptDock`, `_QuestionChoiceTile`, custom answer input, progress dots.
- Apple-like Simplicity 적용 방향: 좋은 방향이다. option tile 카피와 진행 indicator만 더 정제하면 된다.
- Modern UI Elements 적용 방향: option tile과 custom input radius를 통일하고, 선택 상태를 glow보다 background tint 중심으로 맞춘다.
- Smooth Transitions 적용 방향: 다음 질문 이동과 submit loading의 motion scale을 작게 유지한다.
- 모바일 호환성 메모: compact에서는 dock 대신 전용 sheet로 열 수 있어 구조적으로 안전하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_question_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_question_dock_test.dart)

### W24 Permission Prompt Dock

- 목적: 권한 요청을 빠르게 허용 또는 거부하게 한다.
- 현재 정보 구조: warning identity block, request copy, optional patterns, action row.
- 핵심 구성 요소: permission summary, pattern chips, allow/reject actions.
- Apple-like Simplicity 적용 방향: 현 구조를 유지하되 설명 문장과 패턴 노출량을 줄인다.
- Modern UI Elements 적용 방향: warning tone은 남기되 badge와 border를 과하게 중첩하지 않는다.
- Smooth Transitions 적용 방향: 응답 후 dock dismiss는 빠르게, 결과 피드백은 snack bar로 넘긴다.
- 모바일 호환성 메모: compact에서도 dedicated sheet 경로가 있어 안정적이다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

### W25 Session Todo Dock

- 목적: 현재 세션의 to-do 진행 상황을 시야 안에 둔다.
- 현재 정보 구조: progress summary header, collapsible body, active todo preview 구조다.
- 핵심 구성 요소: progress label, collapse button, todo rows, active preview, auto-hide logic.
- Apple-like Simplicity 적용 방향: collapsed state가 기본일 때 가장 유용하다. 완전 펼침보다 summary-first 방식을 계속 유지한다.
- Modern UI Elements 적용 방향: card border와 상단 gradient mask를 최소화하고, 상태 아이콘만 의미를 갖게 한다.
- Smooth Transitions 적용 방향: open/close는 현재 `AnimatedSize` 방향이 맞고, auto-dismiss도 same easing으로 통일한다.
- 모바일 호환성 메모: compact에서는 activity bar 진입점으로 대체돼 별도 공간을 먹지 않는다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_todo_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_todo_dock_test.dart)

### W26 Compact Session Activity Bar

- 목적: compact 세션에서 question, permission, todo, sub-agent를 한 손으로 여는 빠른 표면이다.
- 현재 정보 구조: 수평 스크롤 가능한 pill 버튼 행으로 매우 단순하다.
- 핵심 구성 요소: compact summary buttons, count labels, accent tint.
- Apple-like Simplicity 적용 방향: 현재 구조를 기준형으로 삼고 다른 compact entry surface도 이 정도 단순성을 목표로 잡는다.
- Modern UI Elements 적용 방향: pill radius, muted panel, 얕은 accent border 조합이 적절하다.
- Smooth Transitions 적용 방향: 버튼 탭 후 compact sheet가 같은 계열 bottom-sheet motion으로 이어지면 충분하다.
- 모바일 호환성 메모: compact 전용이며 관련 테스트가 있어 모바일 제품 방향에 가장 잘 맞는 표면 중 하나다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_active_child_sessions_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_active_child_sessions_panel_test.dart), [workspace_todo_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_todo_dock_test.dart)

### W27 Terminal Panel Slot

- 목적: guided sheet나 chat UI로 부족한 작업을 PTY 패널로 이어 준다.
- 현재 정보 구조: open/hidden/expanded state를 가진 reveal slot이고 실제 터미널 표면은 child에서 렌더링한다.
- 핵심 구성 요소: reveal slot, expanded height, hidden state, terminal panel child.
- Apple-like Simplicity 적용 방향: 터미널은 강한 utility surface이므로 장식보다 상태 전환의 명확성이 더 중요하다.
- Modern UI Elements 적용 방향: panel을 별도 layer로 취급하되 workspace 전체와 너무 많은 surface 경쟁을 하지 않게 한다.
- Smooth Transitions 적용 방향: reveal/hide는 현재 clip align 기반이 맞고, 키보드/compact 상태와의 연동만 더 부드럽게 만들면 된다.
- 모바일 호환성 메모: compact terminal focus 처리와 연동돼 있지만 키보드와 함께 움직일 때 시각 복잡도가 높아질 수 있다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart), [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart)

### W28 Compact Workspace Sheet Wrapper

- 목적: compact 모드에서 question, permission, todo, sub-agent 같은 보조 흐름을 공통 sheet 프레임으로 감싼다.
- 현재 정보 구조: drag handle, title row, divider, scroll body를 가진 generic wrapper다.
- 핵심 구성 요소: drag handle, title, close action, scrollable content body.
- Apple-like Simplicity 적용 방향: compact 보조 흐름은 이 wrapper 하나로 통일하는 것이 좋다.
- Modern UI Elements 적용 방향: 배경은 plain surface, top radius 28, 그림자 1계층만 유지한다.
- Smooth Transitions 적용 방향: 모든 compact follow-up sheet는 동일한 height factor와 same easing을 사용한다.
- 모바일 호환성 메모: compact overlay의 공통 기반으로 적합하다.
- 작업 상태: `[x]` 완료. Apple-like 단순화, surface hierarchy, radius/blur/depth 규칙, 모바일 compact 대응을 기준형으로 반영했다.
- 구현 근거 파일: [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)

## 7. 공통 컴포넌트 인벤토리

| 컴포넌트 군 | 현재 사용 위치 | 통일 규칙 | 예외 허용 여부 |
| --- | --- | --- | --- |
| 카드 / 패널 | 홈 패널, import, project actions, git, inbox, settings, MCP | 대형 `24`, 보조 `20`, 내부 카드 `18` 기준으로 통일하고 border + shadow는 한 번만 사용 | review diff, terminal utility surface는 가독성 우선으로 더 각진 스타일 허용 |
| 칩 / 배지 / 상태 표시 | server pill, summary chip, status chip, overview chip, pattern chip | pill 반경 `999`, tone은 `primary/success/warning/danger/muted` 5축만 사용 | context usage ring처럼 수치형 시각화는 별도 규칙 허용 |
| 버튼 / 아이콘 버튼 / floating action | top bar chips, composer buttons, compact activity, snack action | primary filled 1개, secondary outlined/text, icon button 크기 `40/36`, floating 진입점은 표면당 1개 원칙 | destructive dialog CTA는 예외적으로 high-contrast 허용 |
| 입력 필드 / 검색 / 선택 시트 | project picker, command palette, MCP picker, selection sheets, rename dialog | input radius `18`, search field 상단 고정, helper text 최소화, selection sheet frame 재사용 | multiline question custom input은 세로 확장 허용 |
| 시트 / 다이얼로그 / 오버레이 | import, servers, git, inbox, project actions, settings, submit mode, release notes | top radius `28`, close affordance 우상단, glass는 최상위 모달 중심, 내부는 plain card | overflow menu와 snack bar만 blur 적극 사용 허용 |
| 세션 리스트 / 행 아이템 | server cards, project tiles, session tree rows, running session card | 왼쪽 identity, 중앙 text, 오른쪽 action/chevron의 3단 구조 유지 | drag reorder 상태에서는 오른쪽 action 생략 허용 |
| 타임라인 메시지 / 첨부 / 코드 블록 | timeline, attachment grid, structured text, review diff | 텍스트 bubble, media tile, code block 세 가지 기본 surface만 유지 | shell output과 diff view는 monospace emphasis 예외 허용 |
| 모바일 도크 / compact 전환 UI | question dock, permission dock, todo dock, compact activity, pane switcher | 최대 폭 `920`, bottom-aligned, primary CTA 1개, collapse/expand affordance 일관화 | compact activity bar는 수평 스크롤 pill row 예외 유지 |

## 8. 모바일 호환성 매트릭스

| 표면군 | 근거 breakpoint / 테스트 | 현재 동작 | 주요 리스크 | 판정 |
| --- | --- | --- | --- | --- |
| 홈 메인 화면 | `600 / 720 / 1180` 분기, [web_home_screen_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/web_home_screen_test.dart) | 좁은 화면에서는 세로 스택과 compact header 사용 | 상세 패널 길이 증가로 스크롤 피로 | 통과 |
| 홈 시트 / 서버 관리 | modal sheet 구조, form 기반 | Add/Edit/Manage를 시트로 분리 | 긴 폼에서는 스크롤 집중이 필요함 | 통과 |
| 워크스페이스 헤더 / 내비게이션 | `1100` breakpoint, [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart) | compact에서 overflow, drawer, pane switcher로 전환 | 상단 메타와 action chip 수가 여전히 많음 | 통과 |
| 세션 pane / timeline | responsive matrix와 multi-pane tests | compact에서 단일 pane 중심, desktop에서 multi-pane | message variant 수가 많아 폰에서 시각 피로 | 통과 |
| side panel / review / files / context | compact fallback, panel toggle tests | compact에서 side pane 또는 sheet 경로 확보 | 긴 diff에서는 세로 스크롤 집중이 필요함 | 통과 |
| composer / queued follow-up | [workspace_slash_commands_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_slash_commands_test.dart) | busy state에서 queue sheet, terminal focus 시 composer 숨김 | 보조 제어 수가 많아 초심자에게 복잡 | 통과 |
| inbox / git / project actions | dedicated bottom sheet 구조 | 모바일 중심 진입 표면으로 잘 맞음 | git changed file 리스트가 길 때 밀도 상승 | 통과 |
| question / permission / todo flows | [workspace_question_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_question_dock_test.dart), [workspace_todo_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_todo_dock_test.dart) | desktop에서는 dock, compact에서는 sheet/overlay로 전환 | long-form question copy가 길어질 때 높이 증가 | 통과 |
| compact activity bar | [workspace_active_child_sessions_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_active_child_sessions_panel_test.dart), [workspace_todo_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_todo_dock_test.dart) | timeline 위를 덮는 수평 pill bar | chip 개수 증가 시 스크롤 의존 | 통과 |
| selection / MCP / command palette sheets | constrained bottom sheet 프레임 | 검색형 시트 재사용 | 긴 설명 카피는 2줄 이내 유지 권장 | 통과 |
| terminal slot | compact terminal focus handling | 하단 slot reveal과 expanded height 지원 | 키보드와 함께 열릴 때도 slot 계층이 유지됨 | 통과 |

모바일 QA 기준 viewport는 아래 helper를 따른다.

- [responsive_viewports.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/test_helpers/responsive_viewports.dart)
- `320x568`
- `360x740`
- `390x844`
- `430x932`
- `768x1024`
- `1024x768`
- `1366x1024`
- `1280x800`
- `1440x900`
- `2880x900`

## 9. 우선 작업 추천 순서

이번 차수는 아래 순서대로 구현을 완료했다.

1. **Foundation Lock 완료**
   `AppSpacing`, `AppTheme`, `AppSurfaceDecor`를 기준으로 radius, blur, border opacity, shadow depth 토큰을 고정했다.
2. **Home Surface 정렬 완료**
   `H01`부터 `H08`까지 홈, 서버 관리, import, project picker, destructive dialog를 같은 surface hierarchy로 통일했다.
3. **Workspace Shell 정렬 완료**
   `W01`부터 `W06`까지 top bar, sidebar, pane deck, timeline, composer를 Apple-like 밀도와 glass/floating 규칙에 맞췄다.
4. **Workspace Support Surface 정렬 완료**
   `W07`부터 `W18`까지 inbox, git, project actions, settings, command palette, MCP picker, selection/modality 계열을 통일했다.
5. **Side Panel / Review / Mobile Surface 정렬 완료**
   `W19`부터 `W28`까지 review/files/context/diff, dock, compact activity, compact wrapper, terminal slot을 기준형으로 마감했다.
6. **Acceptance Pass 완료**
   `flutter analyze`와 워크스페이스/홈/모바일 회귀 테스트를 다시 통과시켜 완료 상태를 검증했다.

이번 차수의 핵심 완료 묶음은 아래 네 가지다.

- 공통 card / panel / glass surface 토큰 고정
- compact 모드의 primary action / overflow / dock 진입점 정리
- side panel / review / diff / context의 밀도 및 계층 정리
- sheet / dialog / overlay motion 및 visual language 통일

## 10. 구현 근거 파일 링크 모음

### 10.1 앱 엔트리

- [app.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app.dart)
- [app_routes.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_routes.dart)
- [app_release_notes_dialog.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_release_notes_dialog.dart)

### 10.2 디자인 시스템 출발점

- [app_theme.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_theme.dart)
- [app_spacing.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_spacing.dart)
- [app_surface_decor.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_surface_decor.dart)
- [app_snack_bar.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/design_system/app_snack_bar.dart)

### 10.3 홈 영역

- [web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart)
- [web_home_screen_server_management.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen_server_management.dart)
- [project_picker_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/project_picker_sheet.dart)
- [connection_profile_import_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_profile_import_sheet.dart)

### 10.4 워크스페이스 핵심 및 보조 표면

- [workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)
- [workspace_screen_side_panel.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen_side_panel.dart)
- [workspace_inbox_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_inbox_sheet.dart)
- [workspace_git_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_git_sheet.dart)
- [workspace_project_actions_sheet.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_project_actions_sheet.dart)

### 10.5 모바일 / 반응형 검증

- [responsive_viewports.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/test_helpers/responsive_viewports.dart)
- [web_home_screen_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/web_home_screen_test.dart)
- [workspace_session_header_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_session_header_test.dart)
- [workspace_sidebar_root_sessions_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_sidebar_root_sessions_test.dart)
- [workspace_screen_session_switch_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_screen_session_switch_test.dart)
- [workspace_files_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_files_panel_test.dart)
- [workspace_context_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_context_panel_test.dart)
- [workspace_question_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_question_dock_test.dart)
- [workspace_todo_dock_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_todo_dock_test.dart)
- [workspace_active_child_sessions_panel_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_active_child_sessions_panel_test.dart)
- [workspace_slash_commands_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_slash_commands_test.dart)
- [workspace_timeline_activity_test.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/web_parity/workspace_timeline_activity_test.dart)

## 부록 메모

- 이 문서는 디자인 시스템 정렬 작업 문서이며, 2026-03-31 기준 1차 구현과 대표 회귀 검증을 완료한 상태를 반영한다.
- 표면별 `완료`는 유지 가능한 기준형이라는 뜻이며, 토큰 미세 보정 가능성까지 배제하지 않는다.
- 새 UI 작업을 시작할 때는 먼저 이 문서의 표면 ID를 이슈 제목 또는 작업 브랜치 설명에 연결하는 것이 좋다.
