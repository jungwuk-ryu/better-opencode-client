# OpenChamber 대비 PM 관점 기능 격차 분석

작성일: 2026-03-31

## 1. 분석 목적

`openchamber/openchamber`와 우리 앱(`better-opencode-client`)을 비교해, 우리 제품이 무엇을 더 갖춰야 PM 관점에서 경쟁력이 생기는지 정리한다.

이 문서는 "기능이 몇 개 더 많다"는 비교보다 아래 질문에 답하는 데 초점을 둔다.

- 사용자가 왜 OpenChamber를 선택할 가능성이 높은가?
- 우리 앱은 어느 구간에서 사용자의 작업 흐름이 끊기는가?
- 어떤 격차부터 메워야 전환율과 재사용률이 가장 크게 개선되는가?

## 2. 참고한 근거

### OpenChamber

- 저장소 README: <https://github.com/openchamber/openchamber/blob/main/README.md>
- 웹 패키지: <https://github.com/openchamber/openchamber/blob/main/packages/web/package.json>
- 데스크톱 패키지: <https://github.com/openchamber/openchamber/blob/main/packages/desktop/package.json>
- VS Code 확장 패키지: <https://github.com/openchamber/openchamber/blob/main/packages/vscode/package.json>
- 커스텀 테마 문서: <https://github.com/openchamber/openchamber/blob/main/docs/CUSTOM_THEMES.md>

### 우리 앱

- 프로젝트 README: [README.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/README.md)
- 아키텍처 문서: [docs/architecture/foundation-architecture.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/architecture/foundation-architecture.md)
- 릴리즈 노트: [lib/src/app/app_release_notes.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/app/app_release_notes.dart)
- 연결 홈: [lib/src/features/connection/connection_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/connection/connection_home_screen.dart)
- 프로젝트 워크스페이스: [lib/src/features/projects/project_workspace_section.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_workspace_section.dart)
- 웹 패리티 홈: [lib/src/features/web_parity/web_home_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/web_home_screen.dart)
- 웹 패리티 워크스페이스: [lib/src/features/web_parity/workspace_screen.dart](/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart)
- 모바일 전용 기능 계획: [docs/mission-05-app-only-feature-plan.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-05-app-only-feature-plan.md)

## 3. 한 줄 결론

우리 앱은 "호환성과 안정성이 강한 OpenCode 클라이언트"에 가깝고, OpenChamber는 "어디서나 바로 쓰는 OpenCode 작업 환경"에 가깝다.

즉, 현재 가장 큰 부족함은 개별 UI 요소보다도 다음 세 가지다.

1. 모바일 원격 접속을 즉시 성립시키는 온보딩 패키지
2. Git/GitHub까지 닫히는 end-to-end 개발 워크플로
3. 앱 하나를 넘어서는 제품 표면 확장과 배포 경험

## 4. 현재 우리 앱의 강점

OpenChamber 대비 부족한 점을 보기 전에, 우리 앱이 이미 잘하고 있는 부분은 분명하다.

- OpenAPI 문서와 capability probe를 중심으로 설계되어 서버 버전 변화에 강하다.
- unknown field 보존, SSE 복구, 중복 이벤트 방어 등 런타임 안정성 설계가 매우 탄탄하다.
- 저장 서버/프로젝트 pinning, draft 복원 같은 모바일 편의 기능이 이미 들어가 있다.
- 워크스페이스 패리티 측면에서 명령 팔레트, MCP 관리, 권한 자동 허용, diff, terminal, 세션 공유/분기, 토큰 인사이트, 알림 등 핵심 요소를 꽤 많이 확보했다.

즉, 우리 앱의 문제는 "기본기가 부족하다"가 아니라 "제품화된 사용자 여정이 아직 짧다"는 데 있다.

## 5. 핵심 격차 요약

| 영역 | OpenChamber | 우리 앱 현황 | PM 해석 | 우선순위 |
| --- | --- | --- | --- | --- |
| 원격 접속 온보딩 | Cloudflare tunnel, quick/managed 모드, QR, connect link, UI password, Docker/systemd 가이드 제공 | 서버 URL, 계정, 비밀번호를 직접 입력하는 연결 흐름 중심 | "설치 후 바로 접속" 경험에서 크게 밀린다. 특히 모바일 사용자는 설정 한 단계만 늘어나도 이탈률이 높다. | P0 |
| Git/GitHub 실행 폐루프 | staging, commit, push/pull, branch 관리, PR 생성, checks, merge, issue/PR 기반 세션 시작 | diff/리뷰/세션 관리와 terminal은 있으나 GitHub 네이티브 워크플로는 확인되지 않음 | 사용자가 앱 안에서 판단은 해도 최종 실행은 다른 툴로 나가야 한다. 잔존율과 "매일 쓰는 이유"가 약해진다. | P0 |
| 제품 표면 확장 | Web/PWA, macOS desktop, VS Code extension, CLI까지 하나의 생태계로 연결 | Flutter 클라이언트 중심. 다중 채널 전략과 패키징 메시지는 약함 | OpenChamber는 사용 상황별 진입점이 많다. 우리는 강한 단일 클라이언트지만 확장성이 약하다. | P1 |
| 원격 개발 운영 기능 | dev server 실행, SSH port forwarding, remote URL 열기, SSH 기반 원격 인스턴스 연결 | terminal과 프로젝트 선택은 있지만 운영 액션 레이어는 약함 | "보기/대화"를 넘어 "원격 개발을 조작"하는 제품 인상이 약하다. | P1 |
| 에이전트 운영 UX | multi-agent runs, isolated worktree, plan/build mode, 전용 manager | agent/model 전환과 child session 단서는 있으나 전용 orchestration UX는 약함 | 복잡한 작업에서 사용자 통제감이 떨어진다. 고급 사용자가 떠날 수 있다. | P1 |
| 사용자화와 커뮤니티성 | 18+ 테마, JSON 커스텀 테마, shortcut/customization, docs, Discord, 후원, 배포 문서 | preset 테마와 일부 shortcut 표시는 있으나 확장 가능한 사용자화 표면과 커뮤니티 funnel은 제한적 | 애착, 추천, 공유, 커뮤니티 유입 측면에서 불리하다. | P2 |
| 제품 문서와 배포 완성도 | 설치 스크립트, 릴리즈, Docker, systemd, docs package, marketplace extension | README가 개발자용 내부 문서 성격이 강함 | 제품 신뢰도와 도입 장벽 측면에서 손해가 크다. 좋은 기능이 있어도 채택으로 연결되기 어렵다. | P1 |

## 6. 상세 분석

### 6.1 가장 큰 부족함: "모바일 원격 접속이 쉬운 제품"으로 완성되지 않았다

OpenChamber의 가장 강한 포지셔닝은 기능 수보다도 "어디서나 바로 붙는다"는 점이다. README 기준으로 Cloudflare tunnel, QR 기반 온보딩, one-time connect link, UI password, 브라우저/PWA 사용 흐름이 모두 제품 메시지의 중심에 있다.

반면 우리 앱은 연결 프로필, base URL, username/password를 직접 관리하는 구조가 핵심이다. 이 구조는 유연하고 안정적이지만, PM 관점에서는 신규 사용자의 첫 성공 경험을 너무 많이 사용자 책임으로 넘긴다.

이 차이는 단순한 편의성 문제가 아니다.

- OpenChamber는 "접속을 제품이 해결"한다.
- 우리 앱은 "접속을 사용자가 구성"해야 한다.

모바일 원격 앱에서는 이 차이가 전환율에 직접 연결된다. 따라서 현재 최대 격차는 채팅 UI보다 접속 성립 경험이다.

### 6.2 두 번째 부족함: Git/GitHub까지 이어지는 실행 폐루프가 약하다

우리 앱은 이미 review diff, session share/fork/revert, terminal, MCP 관리, 알림, command palette 등 생산성 기능을 많이 갖고 있다. 하지만 OpenChamber는 여기서 한 단계 더 나가 "실행"까지 닫는다.

OpenChamber README에 따르면 다음이 앱 안에 있다.

- Git sidebar
- staging / commit / push / pull
- branch management
- PR 생성
- status checks
- merge actions
- GitHub issue / PR에서 세션 시작

우리 앱은 branch 노출, diff, terminal, tracked file changes 단서는 있지만, GitHub 네이티브 워크플로와 merge-ready 작업선은 저장소 기준으로 드러나지 않는다.

PM 관점에서 이것은 중요한 차이다.

- 우리 앱은 "작업을 보조하는 클라이언트"
- OpenChamber는 "개발 루프를 닫는 작업 환경"

사용자가 매일 여는 앱이 되려면, 확인과 대화뿐 아니라 최종 실행 지점까지 남아 있어야 한다.

### 6.3 세 번째 부족함: 제품 표면이 하나의 앱에 갇혀 있다

OpenChamber는 Web/PWA, desktop, VS Code extension, CLI를 한 제품 경험으로 묶고 있다. 사용자는 상황에 따라 진입점을 바꿔도 같은 브랜드와 같은 워크플로를 이어간다.

우리 앱은 Flutter 기반이라 기술적으로는 여러 플랫폼 여지가 있지만, 현재 제품 메시지와 구조는 "클라이언트 하나"에 더 가깝다. 이 차이는 곧 채널 전략 차이다.

- OpenChamber: 상황별 entry point를 넓혀 adoption을 키움
- 우리 앱: 특정 사용 환경에선 강하지만, 생태계 확장성이 약함

특히 OpenChamber의 VS Code extension은 "개발자가 이미 있는 자리"에 진입한다는 점에서 매우 강력하다. 우리 앱이 바로 extension까지 따라갈 필요는 없지만, 최소한 웹/PWA나 deep-link 중심의 연속성 전략은 더 선명해야 한다.

### 6.4 원격 개발 운영 기능이 아직 제품 기능으로 드러나지 않는다

OpenChamber는 terminal뿐 아니라 다음을 제품 기능으로 포장한다.

- dev server 실행
- SSH port forwarding
- remote URL 열기
- remote instance 연결

우리 앱은 terminal과 프로젝트 탐색이 잘 되어 있지만, 운영 액션을 추상화한 "Project Actions" 계층은 보이지 않는다. 사용자는 결국 셸로 내려가서 직접 해야 한다.

모바일 원격 사용자는 특히 작은 화면에서 반복 명령을 직접 치는 것을 불편하게 느낀다. 따라서 이 영역은 단순 power-user 기능이 아니라 모바일 제품 차별화 포인트가 될 수 있다.

### 6.5 고급 사용자를 위한 orchestration UX가 약하다

우리 앱도 agent/model 전환, child session, session branching 등 고급 기능 단서를 갖고 있다. 그러나 OpenChamber는 multi-agent runs, isolated worktree, plan/build mode, agent manager를 전면에 내세운다.

이는 단순히 "기능 더하기"가 아니라 사용자의 통제감을 높인다.

- 어떤 에이전트가 무엇을 하고 있는지 보임
- 여러 결과를 나란히 비교 가능
- 계획과 실행이 분리되어 장기 작업 관리가 쉬움

우리 앱은 기반은 있으나, 고급 사용자가 바로 감지하는 운영 표면은 아직 약하다. 추정컨대 현재 구조는 "가능하지만 제품처럼 보이지 않는" 상태에 가깝다.

### 6.6 문서, 배포, 커뮤니티 측면의 제품 완성도가 낮다

OpenChamber는 README만 보더라도 배포, 설치, 커뮤니티, docs, 후원, 확장 채널까지 정돈되어 있다. 반면 우리 앱 README는 테스트와 내부 동작 설명 중심이다.

이 차이는 PM 관점에서 매우 중요하다.

- 사용자는 설치 전 README에서 제품 신뢰를 판단한다.
- 팀 외부 피드백은 문서와 배포 체계가 있을 때만 쌓인다.
- 기능 격차보다 먼저 "알려지지 않는 제품" 문제가 생길 수 있다.

현재 우리 앱은 기술적으로는 꽤 진전되어 있지만, 제품 패키징 레이어가 얇아서 외부 채택 가능성이 낮다.

## 7. 무엇을 먼저 해야 하는가

### Top 3 우선순위

1. 원격 접속 온보딩 패키지
   - 목표: 사용자가 앱 설치 후 5분 안에 첫 연결 성공
   - 제안: QR 연결, 1회용 connect link, 간단한 reverse tunnel/relay 연동, 서버 측 password handshake, 연결 진단 위저드

2. Git/GitHub 폐루프 최소 버전
   - 목표: "읽기"가 아니라 "완료"까지 앱 안에서 끝나게 만들기
   - 제안: 브랜치 상태, stage/commit/push, PR 열기, check 상태 조회, issue/PR에서 세션 열기

3. Project Actions 레이어
   - 목표: 모바일에서도 반복 운영 작업을 한 번 탭으로 수행
   - 제안: dev server 실행, 등록된 명령 실행, 최근 URL 열기, 포트 포워딩 프리셋, SSH 연결 상태 카드

## 8. 추천 로드맵

### Phase 1: 연결 성공률 개선

- QR / deep link 기반 서버 연결
- 연결 테스트 체크리스트
- 프로필 공유/가져오기
- 첫 연결용 튜토리얼/샘플 서버 흐름

### Phase 2: 개발 루프 닫기

- 브랜치 상태와 변경 파일 요약
- stage / commit / push
- PR 생성 또는 기존 PR 연결
- check 상태 read-only 표시

### Phase 3: 모바일 원격 차별화

- Project Actions
- 원격 서비스 상태 카드
- 포트 포워딩/링크 실행
- 음성 입력 또는 hands-free prompt 보조

### Phase 4: 제품 확장

- 외부 사용자용 README/문서/릴리즈 정비
- 웹/PWA 또는 lightweight desktop continuity 전략
- GitHub/IDE 연계 여부 재평가

## 9. 복제하면 안 되는 것

OpenChamber의 모든 기능을 그대로 따라가는 것은 바람직하지 않다.

특히 아래는 당장 복제 우선순위가 낮다.

- VS Code extension 전체 복제
- 광범위한 테마 생태계
- 후원/커뮤니티 기능 확장

우리 앱의 핵심 JTBD는 "모바일에서 원격 OpenCode 작업을 안정적으로 이어가는 것"이므로, 먼저 접속 성립과 실행 폐루프를 해결해야 한다.

## 10. 최종 판단

OpenChamber 대비 우리 앱이 가장 부족한 것은 "기능 개수"가 아니라 "사용자 여정의 닫힘"이다.

현재 우리 앱은 안정적이고 호환성 높은 클라이언트다. 하지만 사용자가 실제로 체감하는 경쟁력은 아래 순서로 결정된다.

1. 얼마나 빨리 접속되는가
2. 앱 안에서 어디까지 끝낼 수 있는가
3. 상황이 바뀌어도 같은 제품 경험을 이어갈 수 있는가

이 기준으로 보면, 우리 앱의 가장 시급한 보완점은 다음 세 가지로 요약된다.

- 원격 접속 온보딩
- Git/GitHub 실행 워크플로
- 원격 개발 운영 액션의 제품화

이 세 가지가 보강되면, 현재 우리가 이미 가진 안정성/호환성 강점이 사용자 가치로 훨씬 더 크게 전환될 가능성이 높다.
