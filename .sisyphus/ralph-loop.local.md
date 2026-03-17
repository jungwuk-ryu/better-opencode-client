---
active: true
iteration: 1
completion_promise: "DONE"
initial_completion_promise: "DONE"
started_at: "2026-03-17T10:35:47.238Z"
session_id: "ses_304a252a8ffe7wIUDLPQthKXzr"
ultrawork: true
strategy: "continue"
message_count_at_start: 2
---
아래의 계획을 차근차근 모두 완료하라. 각 단계는 스스로 세분화하여 작업 하나하나를 오랜 시간이 걸리더라도 완벽하게 해내겠다는 생각으로 진행하라. 또한, 원자적 커밋을 통해 복구할 수 있도록 하라. 만약 특정 단계들을 병렬로 진행할 수 있다면 그렇게 해도 된다. 필요시 opencode 리포지토리를 다운 받아서 참고하라.
⸻

OpenCode Web 100% 대응 Flutter 클라이언트 구현 플랜

1) 제품 목표와 완료 기준

이 프로젝트의 목표는 Flutter 기반의 OpenCode-compatible adaptive client를 만드는 것이다.
디자인 톤은 Luma.com처럼 세련되고 고급스럽게, 그러나 정보 구조와 레이아웃은 OpenCode Web과 거의 동일하게 유지한다.

완료 기준은 다음과 같다.
	•	OpenCode Web의 핵심 기능을 가능한 한 전부 지원한다.
	•	프로젝트/세션/채팅/툴/파일/터미널/설정/에이전트/모델/권한 흐름까지 끊김 없이 동작한다.
	•	다국어를 지원한다.
	•	성능이 충분히 최적화되어 긴 세션과 스트리밍에서도 부드럽게 동작한다.
	•	현재 버전뿐 아니라 향후 OpenCode 버전 변화에도 최대한 자동 적응하도록 설계한다.

⸻

2) 절대 원칙
	1.	이 앱은 “웹 화면 모사”가 아니라 OpenCode 서버용 정식 클라이언트로 만든다.
	2.	UI부터 만들지 말고, 먼저 서버 handshake / capability detection / 상태 모델 / SSE 레이어를 만든다.
	3.	특정 OpenCode 버전에 API를 고정하지 않는다.
	4.	레이아웃은 OpenCode Web과 최대한 같게, 시각 스타일만 Luma 감성으로 덮는다.
	5.	미래 대응은 “예측”이 아니라 spec 기반 적응으로 해결한다.

⸻

3) 0단계 — 패리티 범위 확정과 서버 능력 탐색

가장 먼저 해야 할 일은 네가 적은 목록을 구현하는 게 아니라, 현재 OpenCode Web/Server가 실제로 제공하는 기능 범위를 정식으로 캡처하는 것이다.

초기 연결 시 아래 순서로 서버 capability를 수집한다.
	•	GET /global/health 로 서버 정상 여부와 버전을 읽는다.
	•	GET /doc 으로 OpenAPI 3.1 spec을 가져온다.
	•	GET /config, GET /config/providers, GET /provider, GET /provider/auth, GET /agent 를 읽어 설정/모델/에이전트/인증 가능 범위를 확인한다.
	•	GET /experimental/tool/ids, GET /experimental/tool?provider=<p>&model=<m> 로 도구 스키마/도구 가용성을 동적으로 확인한다. 공식 서버 문서에는 health, spec, providers, sessions, messages, files, LSP/formatter/MCP, agents, auth, events, docs, experimental tool endpoints까지 정리돼 있다.  ￼

이 단계의 산출물:
	•	기능 패리티 매트릭스
	•	버전별 capability map
	•	UI feature flags
	•	fallback 정책

추가로, legacy config 호환 shim도 여기서 설계한다.
Permissions 문서에 따르면 v1.1.1부터 예전 tools boolean 설정은 deprecated 되었고 permission으로 합쳐졌지만, 하위 호환은 여전히 유지된다. 즉, 클라이언트는 구형/신형 설정 형태 둘 다 읽고 써야 한다.  ￼

⸻

4) 1단계 — 저장소/Flutter 부트스트랩

이제서야 부트스트랩을 한다.
	•	git init
	•	flutter create
	•	앱 구조를 기능 단위로 나눈다:
	•	core/network
	•	core/spec
	•	core/session-state
	•	features/connection
	•	features/projects
	•	features/chat
	•	features/files
	•	features/tools
	•	features/terminal
	•	features/settings
	•	design_system
	•	i18n

이 단계에서 반드시 같이 만드는 것:
	•	OpenAPI model/codegen 파이프라인
	•	SSE transport 레이어
	•	로컬 persistence 레이어
	•	debug build flavor
	•	mock server/spec fixture 구조

⸻

5) 2단계 — 연결, 주소 입력, 서버 인증, 서버 탐지

네 초안의 “opencode 접속 기능 구현(로그인, 주소 입력)”은 실제로는 더 크게 쪼개야 한다.

구현 범위:
	•	서버 주소 입력
	•	저장된 서버 목록
	•	최근 연결 목록
	•	연결 테스트
	•	HTTP Basic Auth 입력
	•	mDNS 기반 서버 탐지
	•	CORS/hostname 안내
	•	네트워크/로컬 서버 구분

OpenCode Web/Server 문서에는 hostname, port, mdns, mdnsDomain, cors, OPENCODE_SERVER_PASSWORD, OPENCODE_SERVER_USERNAME 지원이 명시돼 있고, 웹은 세션 홈과 서버 상태 화면도 제공한다.  ￼

여기서 중요한 구현 원칙:
	•	연결 화면은 단순 URL input이 아니라 server profile manager 여야 한다.
	•	첫 연결 시 자동으로:
	•	health 체크
	•	spec fetch
	•	provider/auth methods fetch
	•	capability map 생성
	•	연결 실패 시:
	•	auth 실패
	•	CORS 실패
	•	spec fetch 실패
	•	버전 미지원
	•	SSE 미연결
를 분리해서 보여준다.

⸻

6) 3단계 — 버전 호환 아키텍처

이 프로젝트의 핵심은 UI가 아니라 호환성 계층이다.

반드시 이렇게 설계한다.
	•	version만 보지 말고 spec + endpoint existence + schema shape를 함께 본다.
	•	클라이언트 내부에 CapabilityRegistry를 둔다.
	•	예:
	•	canShareSession
	•	canForkSession
	•	canSummarizeSession
	•	hasExperimentalTools
	•	hasMcpAuth
	•	hasTuiControl
	•	hasProviderOAuth
	•	알 수 없는 필드는 버리지 말고 raw JSON 그대로 보존한다.
	•	설정 저장 시 “알려진 필드만 다시 serialize” 하지 말고 unknown field preservation을 보장한다.

또 하나 중요하다. 프로젝트 이슈 문서에 따르면 현재 OpenCode Web 구조는 Local Server + Remote UI Proxy로 설명되어 있고, 별도 CDN에서 프런트엔드 자산을 받아오는 구조 때문에 로컬 버전과 프런트 번들이 어긋나 blank page가 난 사례가 있었다. 따라서 이 Flutter 앱은 그런 구조를 따라 하지 말고 클라이언트 자산을 앱에 번들링해야 한다.  ￼

⸻

7) 4단계 — 프로젝트 선택 화면

네 초안의 “프로젝트 선택 화면”은 아래처럼 확장해야 한다.

구현해야 하는 요소:
	•	현재 프로젝트 표시
	•	최근 프로젝트 목록
	•	서버가 인식하는 프로젝트 목록
	•	수동 경로 입력
	•	폴더 브라우저
	•	검색 기반 오픈
	•	프로젝트 메타정보(path, vcs)
	•	프로젝트별 마지막 세션/상태

서버 문서는 /project, /project/current, /path, /vcs를 제공한다.  ￼

그리고 이 화면은 반드시 강하게 만들어야 한다.
최근 이슈에서 OpenCode Web의 “Open Project”가 일부 폴더를 찾지 못한다는 보고가 있었다. 그러니 네 앱은 다음 4개를 모두 제공해야 한다.
	•	recent에서 열기
	•	서버가 알려준 project 목록에서 열기
	•	직접 경로 입력
	•	폴더 탐색기에서 열기

이걸 해야 “검색 안 되는 프로젝트” 회귀를 피할 수 있다.  ￼

⸻

8) 5단계 — 전체 레이아웃 구현

여기서부터 네가 원한 OpenCode Web 유사 레이아웃을 만든다.

기본 구조:
	•	왼쪽: 프로젝트 관리 + 세션 패널
	•	가운데: 채팅 섹션
	•	오른쪽: 문맥 패널
	•	파일 트리
	•	diff
	•	todo
	•	tools
	•	terminal
	•	settings/context panels

원칙:
	•	정보 구조는 OpenCode Web과 거의 동일
	•	스타일만 Luma 감성
	•	즉, “레이아웃 복제 + 스킨 교체” 방식으로 간다.

시각 규칙:
	•	여백 넓게
	•	카드 경계 부드럽게
	•	미세한 glass/gradient 사용
	•	과한 neon 금지
	•	고급스러운 타이포 우선
	•	어두운 배경에서도 대비 확보
	•	애니메이션은 작고 짧게

⸻

9) 6단계 — 세션/서브세션 구조

OpenCode는 단순 1차원 채팅이 아니다.
Agent 문서에 따르면 subagent가 child session을 만들 수 있고, parent/child navigation 개념이 있다. built-in primary agent는 build, plan, built-in subagent는 general, explore다.  ￼

따라서 세션 UI는 다음을 지원해야 한다.
	•	세션 목록
	•	세션 상태(idle / active / error)
	•	child session tree
	•	parent ↔ child 전환
	•	세션 제목 수정
	•	세션 삭제
	•	세션 fork
	•	세션 share/unshare
	•	세션 summarize
	•	세션 revert / unrevert
	•	세션 diff 보기
	•	세션 abort
	•	session init (AGENTS.md 생성 흐름)

이 부분은 서버의 session/message API 범위에 맞춰 설계한다.  ￼

⸻

10) 7단계 — 채팅 화면 코어

이 단계가 실제 핵심 화면이다.

구현 원칙:
	•	초기 메시지 fetch
	•	이후는 SSE 기반 실시간 갱신
	•	메시지 단위가 아니라 message part 단위로 렌더링
	•	스트리밍 delta merge
	•	긴 세션에서도 성능 유지

프로젝트 architecture 이슈 문서에는 OpenCode 클라이언트가 REST + SSE로 동작하고, message.updated, message.part.updated, message.removed, session.status, todo.updated, question.asked, permission.asked 같은 이벤트를 처리한다고 정리돼 있다. 또한 part 타입도 text/tool/file/reasoning/snapshot/patch/agent/retry/compaction/subtask/step-start/step-finish 등으로 설명된다.  ￼

즉, 채팅 화면은 아래 renderer registry를 가져야 한다.
	•	text part renderer
	•	reasoning/thinking renderer
	•	tool execution renderer
	•	file reference renderer
	•	snapshot renderer
	•	patch/diff renderer
	•	subtask/agent renderer
	•	retry/step/compaction renderer

⸻

11) 8단계 — 모델, agent, thinking 정도, 자동 수락

네 초안의 이 부분은 아주 중요하지만, 구현을 단순 toggle 몇 개로 만들면 안 된다.

모델 선택

OpenCode는 Models.dev 기반으로 75개 이상 provider와 local model까지 지원한다. 모델은 provider/model 형식으로 선택되고, provider/model별 옵션도 설정 가능하다.  ￼

thinking 정도

이건 범용 숫자 슬라이더가 아니라 provider별 의미가 다른 variant/options로 매핑해야 한다.
	•	Anthropic: high, max
	•	OpenAI: none, minimal, low, medium, high, xhigh
	•	Google: low, high

또 모델 옵션 예시로 reasoningEffort, textVerbosity, reasoningSummary, Anthropic의 thinking.budgetTokens 같은 설정도 문서화돼 있다.  ￼

즉 UI는 이렇게 만든다.
	•	공통 UX: 빠름 / 균형 / 깊게 생각 / 최대
	•	내부 매핑: provider/model별 variant 혹은 options

agent 선택

반드시 다음을 지원:
	•	primary agents
	•	subagents
	•	custom agents
	•	hidden/internal agents
	•	per-agent tools
	•	per-agent permissions
	•	task permissions

Agent 문서는 per-agent model/tools/permissions, hidden subagent, task permission 제어까지 설명한다.  ￼

자동 수락

“자동 수락”은 단순 스위치가 아니라 permission policy UI로 구현한다.

Permissions 문서는 allow / ask / deny와 승인 시 once / always / reject 흐름을 설명한다. 또 agent별 override도 가능하다.  ￼

그러므로 UI는 최소한 다음을 가져야 한다.
	•	이번만 허용
	•	이번 세션에서 항상 허용
	•	거부
	•	도구별 정책 변경
	•	agent별 정책 변경
	•	bash/edit/webfetch 등 세부 규칙 편집

⸻

12) 9단계 — 질문/권한/인터럽트 흐름

OpenCode는 실행 중 AI가 질문을 하거나 권한을 요청할 수 있다. 관련 architecture 문서는 question.asked와 permission.asked 이벤트 및 대응 흐름을 설명한다.  ￼

따라서 채팅 UI 외에 반드시 필요한 것:
	•	question modal
	•	permission sheet
	•	pending requests center
	•	interrupt/abort UX
	•	session running state indicator
	•	multi-step task 진행 상태 표시

이 흐름을 잘 못 만들면 auto accept, tool approval, interactive MCP/auth 같은 핵심 기능이 다 깨진다.

⸻

13) 10단계 — todo 목록 및 각종 도구 지원

네 초안의 “todo 목록 섹션 및 각종 툴 지원”은 아래 범위로 재정의해야 한다.

Todo
	•	세션별 todo fetch
	•	실시간 todo 갱신
	•	완료/진행중/대기 상태 렌더링
	•	todo 변화 히스토리

Built-in tools

OpenCode tools 문서에는 bash, edit, write, read, grep, glob, list, lsp, patch, skill, todowrite, todoread, webfetch, websearch, question 등이 정리돼 있다.  ￼

Files and search

서버 문서 기준으로 다음을 UI에 반영한다.
	•	파일 트리
	•	파일 읽기
	•	파일 상태
	•	텍스트 검색
	•	파일명 검색
	•	symbol 검색
	•	diff 보기

관련 API는 /find, /find/file, /find/symbol, /file, /file/content, /file/status 다.  ￼

Experimental tools

/experimental/tool/ids 와 /experimental/tool?provider=&model= 도 지원해서, 특정 모델/버전에서 어떤 tool schema가 활성화되는지 보여주는 개발자 패널을 만든다.  ￼

⸻

14) 11단계 — 터미널 지원

터미널은 두 층으로 나눠 구현한다.

A. 빠른 shell 실행
	•	/session/:id/shell 기반
	•	한 줄 명령 실행
	•	명령 결과를 채팅과 연결

B. 전체 터미널/TUI attach

OpenCode Web/CLI 문서에는 opencode attach 로 이미 실행 중인 web/serve 서버에 TUI를 붙여 웹과 터미널이 같은 세션/상태를 공유할 수 있다고 명시돼 있다.  ￼

따라서 앱은 다음을 제공해야 한다.
	•	embedded terminal view
	•	attach URL 복사
	•	1-click attach helper
	•	현재 session context로 attach
	•	TUI와 web 간 상태 동기 표시

그리고 반드시 회귀 테스트 항목으로 넣어야 한다.
실제 이슈에서 웹 터미널 클릭 후 입력이 채팅창으로 들어가는 문제가 보고되었다.  ￼

⸻

15) 12단계 — 설정 화면 전체 지원

네 초안의 “opencode web에 있는 모든 설정 기능 지원”은 form editor + raw editor 두 레이어로 만들어야 한다.

Config 문서 기준으로 최소 지원 범위는 아래다.
	•	server
	•	tools
	•	provider
	•	model
	•	small_model
	•	theme / tui.json
	•	agent
	•	default_agent
	•	share
	•	command
	•	keybinds
	•	autoupdate
	•	formatter
	•	permission
	•	compaction
	•	watcher
	•	mcp
	•	plugin
	•	instructions
	•	disabled_providers
	•	enabled_providers
	•	experimental  ￼

또한 설정 계층도 보여줘야 한다.
	•	remote org config (.well-known/opencode)
	•	global config
	•	custom config path
	•	project config
	•	TUI config (tui.json)

Config 문서는 remote → global → custom → project 우선순위와, TUI 전용 설정은 tui.json을 쓰는 방식을 설명한다.  ￼

중요 구현 포인트:
	•	guided form UI
	•	raw JSON/JSONC editor
	•	schema 기반 validation
	•	unknown key 보존
	•	config diff preview
	•	적용 전/후 비교
	•	revert button
	•	project/global scope 전환

그리고 experimental은 문서가 불안정하고 바뀔 수 있다고 명시하므로, 별도 “실험 항목” 섹션으로 격리하고 raw editor 우선으로 처리한다.  ￼

⸻

16) 13단계 — MCP / LSP / Formatter / Provider Auth

이건 종종 빠뜨리지만 100% parity 목표라면 필수다.

MCP

MCP 문서는 local/remote server, headers, OAuth auto-detect, 수동 auth/logout/debug, enabled 토글까지 지원한다고 설명한다.  ￼

따라서 UI는 다음이 필요하다.
	•	MCP 목록
	•	enabled/disabled
	•	local/remote 유형 표시
	•	OAuth 상태
	•	auth 시작/로그아웃/debug
	•	timeout, headers, env 편집
	•	per-agent/per-tool enable 전략

LSP / Formatter

서버 문서에는 /lsp, /formatter status API가 있다. 그러므로 우측 패널 혹은 설정/개발자 패널에서 상태를 볼 수 있어야 한다.  ￼

Provider Auth

서버는 /provider/auth, OAuth authorize/callback, /auth/:id credential set API를 노출한다. CLI 문서도 provider auth login/list/logout 흐름을 설명한다.  ￼

즉 앱은:
	•	provider 연결 상태
	•	auth 방식(api key / oauth 등)
	•	connect/disconnect
	•	에러 재인증
	•	provider별 credential form
을 가져야 한다.

⸻

17) 14단계 — 다국어 지원

다국어는 마지막에 붙이면 100% 실패한다. 처음부터 한다.

원칙:
	•	모든 UI 문자열 externalize
	•	plural/date/number locale-aware 처리
	•	RTL 대비
	•	locale hot-switch
	•	번역 누락 fallback
	•	서버/모델/provider 고유명사는 그대로 두고 설명문만 번역

그리고 설정/권한/오류/툴 상태 메시지처럼 동적 문장이 많으니, 문자열 설계부터 ICU 스타일로 간다.

⸻

18) 15단계 — 성능 최적화

“매우 최적화” 요구를 만족하려면 이것도 처음부터 구조에 넣어야 한다.

필수 항목:
	•	session/message list virtualization
	•	diff virtualization
	•	file tree lazy load
	•	normalized state store
	•	delta 기반 partial update
	•	immutable snapshot cache
	•	hot state / cold state 분리
	•	spec/config/provider/model 캐시 분리
	•	expensive markdown/diff 렌더 memoization
	•	이미지/대용량 첨부 lazy render
	•	오래된 session 정리 정책
	•	background parse isolate

또 스트리밍 회복력이 매우 중요하다.
architecture 문서는 SSE 연결과 heartbeat를 설명하고, 실제 이슈 #8002에서는 불안정한 네트워크에서 message.part.updated 스트림이 중간에 끊기면 UI가 멈출 수 있다는 보고가 있다. 따라서 반드시:
	•	reconnect with backoff
	•	heartbeat timeout
	•	stale stream detection
	•	session refetch fallback
	•	non-streaming recovery mode
	•	“실행 중인데 스트림이 죽은 상태” 탐지
를 구현한다.  ￼

⸻

19) 16단계 — 모바일/태블릿/데스크톱 반응형

Flutter라고 해서 자동 반응형이 되지 않는다.
최근 이슈에는 모바일/태블릿에서 auto focus, 이상한 색상, 우측 탭 폭, thinking/edits/subagents 노출 부족, copy/paste, fork/undo/redo 부족 등이 불편점으로 보고됐다.  ￼

반드시 별도 레이아웃을 만든다.
	•	desktop: 3-pane
	•	tablet landscape: 2-pane + collapsible right drawer
	•	tablet portrait: chat 우선 + bottom sheet tools
	•	mobile: single pane + stacked drawers

주의점:
	•	입력창 auto focus 기본 금지
	•	키보드 올라올 때 layout 깨짐 방지
	•	right utility를 너무 얇게 만들지 말 것
	•	touch target 크게
	•	copy/paste와 text selection 최적화
	•	long press actions 지원

⸻

20) 17단계 — QA, 회귀 테스트, 릴리즈

이 단계는 절대 “마지막에 대충 확인”하면 안 된다.
처음부터 체크리스트를 만든다.

필수 회귀 시나리오
	•	프로젝트 열기/검색/수동 경로
	•	터미널 focus/input
	•	thinking collapse/분리
	•	model variant switching
	•	agent/subagent child session navigation
	•	share/fork/undo/redo/revert/unrevert
	•	todo 실시간 갱신
	•	file search/symbol search
	•	dropped SSE recovery
	•	mobile/tablet layout
	•	config unknown field preservation
	•	MCP auth
	•	provider reconnect
	•	asset/version mismatch 대비

실제 웹 이슈들만 봐도 프로젝트 열기, 터미널 입력, thinking 구분, 모바일 UX, stale frontend mismatch가 모두 회귀 포인트로 드러난다.  ￼

버전별 검증
	•	현재 stable
	•	직전 stable
	•	한두 개 이전 버전
	•	알려진 beta/nightly fixture
	•	spec snapshot diff 테스트

개발자용 디버그 화면

서버 문서에는 /event, /log, /doc, TUI control endpoints까지 있으니, 개발자/debug 메뉴를 반드시 둔다.  ￼

디버그 화면에 넣을 것:
	•	raw event viewer
	•	raw session/message inspector
	•	raw config inspector
	•	raw OpenAPI spec viewer
	•	capability flags viewer
	•	provider auth diagnostics
	•	MCP diagnostics
	•	SSE reconnect log

⸻

21) 네 초안에서 빠졌던 핵심 항목 요약

네가 적은 원래 항목에서 반드시 추가되어야 하는 건 이거다.
	•	버전 감지 + OpenAPI 기반 capability probing
	•	SSE 실시간 이벤트 아키텍처
	•	message part renderer registry
	•	question / permission UI
	•	child session tree
	•	share / fork / summarize / revert / unrevert / diff / abort / init
	•	provider auth / MCP auth
	•	file tree / file search / symbol search / file status
	•	LSP / formatter / MCP 상태 패널
	•	schema 기반 설정 편집기
	•	unknown future config 필드 보존
	•	네트워크 불안정 시 스트림 복구
	•	known regression suite

⸻

22) 최종 한 줄 지시

이 프로젝트는 “OpenCode Web을 흉내 내는 Flutter UI”가 아니라, “OpenCode 현재/미래 버전에 적응하는 spec-driven Flutter client”로 구현한다. 레이아웃은 OpenCode Web과 거의 같게, 시각 스타일만 Luma 감성으로 고급화한다.
