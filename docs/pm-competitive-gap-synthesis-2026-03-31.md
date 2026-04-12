# PM 경쟁사 통합 갭 분석 및 실행 기준서

작성일: 2026-03-31  
대상 제품: `better-opencode-client (BOC)` vs `CodeNomad` / `OpenChamber`

이 문서는 아래 두 문서를 실행 기준으로 재구성한 통합본이다.

- `docs/competitive-analysis-codenomad-2026-03-31.md`
- `docs/openchamber-pm-gap-analysis.md`

목적은 단순 병합이 아니다. 이후 제품 결정, 구현 우선순위, 문서화 작업이 모두 이 문서를 기준으로 움직일 수 있도록 `단일 판단 기준(single source of truth)`을 만드는 데 있다.

## 1. 한 줄 결론

현재 우리 앱은 `안정적이고 호환성 높은 OpenCode 클라이언트`에 가깝고, 두 경쟁사는 공통적으로 `원격 접속을 빠르게 성립시키고 앱 안에서 작업을 끝내게 하는 제품 경험`에서 앞서 있다.

따라서 앞으로의 기준은 기능 개수 경쟁이 아니라 아래 한 문장으로 정리된다.

> `모바일에서 가장 빠르고 신뢰성 있게 원격 OpenCode 작업을 이어가는 companion`이 된다.

## 2. 왜 이 문서가 필요한가

기존 두 문서는 각각 의미가 분명했다.

- CodeNomad 분석은 `제품 포지셔닝`, `운영 콘솔`, `모바일 입력/접근성`, `시장 신뢰 신호` 문제를 더 강하게 드러냈다.
- OpenChamber 분석은 `원격 접속 온보딩`, `Git/GitHub 폐루프`, `제품 표면 확장`, `원격 운영 액션` 문제를 더 구체적으로 드러냈다.

하지만 실제 작업으로 옮길 때는 문서가 둘로 나뉘어 있으면 우선순위 판단이 흔들릴 수 있다.  
이 통합본은 두 문서의 겹치는 결론을 하나의 실행 프레임으로 묶는다.

## 3. 제품 방향 결정

### 추천 포지션

우리가 지금 집중해야 할 포지션은 아래다.

- `mobile-first remote OpenCode companion`
- 핵심 JTBD: 밖에 있거나 자리에서 벗어난 상태에서도 `빠르게 접속하고`, `상황을 파악하고`, `승인/수정/완료`까지 이어가는 것

### 지금 당장 하지 않을 방향

아래 방향은 장기 검토는 가능하지만, 현재 우선순위로 두면 안 된다.

- 데스크톱 운영 콘솔 전면전
- VS Code extension 전체 복제
- 광범위한 테마/커뮤니티 생태계 확장
- 다중 채널 제품군을 먼저 넓히는 전략

### 이유

우리의 현재 강점은 이미 분명하다.

- OpenAPI 및 capability probe 기반 설계
- SSE 복구, unknown field 보존 등 안정성
- 워크스페이스 패리티 상당수 확보
- 모바일 편의 기능의 기초 보유

즉, 지금 필요한 것은 기반 기술을 더 증명하는 일이 아니라, 그 기반을 `모바일 원격 제품 경험`으로 다시 포장하고 닫는 일이다.

## 4. 경쟁사 통합 인사이트

| 공통 인사이트 | CodeNomad가 보여준 것 | OpenChamber가 보여준 것 | 우리에게 필요한 결론 | 우선순위 |
| --- | --- | --- | --- | --- |
| 원격 접속이 제품의 본체여야 한다 | PWA, HTTPS/TLS, auth 가이드, browser/server 흐름 | Cloudflare tunnel, quick mode, QR, connect link, UI password | 접속 자체를 사용자가 구성하게 두지 말고 제품이 성공시켜야 한다 | P0 |
| 앱 안에서 작업이 끝나야 한다 | repo-wide changes, session 운영 패널, 장시간 세션 UX | stage/commit/push, PR/checks, issue/PR 기반 세션 시작 | 읽기와 대화만이 아니라 실행과 완료까지 닫아야 한다 | P0 |
| 헤비 유저 운영성이 중요하다 | multi-instance, session search, worktree-aware UX, background visibility | project actions, remote URL 열기, SSH/운영 액션, agent manager | 세션/프로젝트/작업을 오래 다뤄도 피로하지 않은 운영 레이어가 필요하다 | P1 |
| 모바일 차별화는 편의가 아니라 입력 비용 절감이어야 한다 | voice input, playback, RTL, 긴 대화 성능 | anywhere access, quick connect, remote workflow 단축 | 이동 중 사용, 한 손 사용, 승인/triage 중심 플로우를 강화해야 한다 | P1 |
| 제품 패키징과 신뢰 신호가 채택을 좌우한다 | 제품 언어 중심 README, 릴리즈 흐름, 커뮤니티 신호 | 설치/배포/docs/패키지 표면 정비 | 기술 설명보다 제품 가치와 도입 경로를 먼저 보여줘야 한다 | P1/P2 |

## 5. 우리가 실제로 부족한 것

두 문서를 합치면 부족함은 아래 5개 워크스트림으로 정리된다.

### WS1. Connection Success Package

문제 정의:
현재 우리 앱은 연결 자체는 가능하지만, `첫 연결 성공`을 제품이 보장하지는 못한다.

핵심 질문:
사용자가 앱 설치 후 5분 안에 첫 원격 연결에 성공할 수 있는가?

필수 산출물:

- QR 또는 deep link 기반 서버 연결 가져오기
- 연결 진단 위저드
- TLS/auth/capability 상태를 설명하는 체크리스트
- 현재 연결된 `서버 / 프로젝트 / 세션`을 강하게 보여주는 신뢰 UI
- 프로필 공유 또는 가져오기 흐름

성공 기준:

- 첫 연결 시간 단축
- 연결 실패 원인 가시화
- 연결 직후 사용자가 "어디에 붙어 있는지" 혼동하지 않음

우선순위:
`P0`

### WS2. Completion Loop In App

문제 정의:
현재 우리 앱은 확인과 대화는 가능하지만, 최종 완료 단계에서 다른 툴로 이탈할 가능성이 높다.

핵심 질문:
사용자가 앱 안에서 `판단 -> 수정 -> 커밋/푸시/PR 확인`까지 최소 루프를 닫을 수 있는가?

필수 산출물:

- 브랜치 상태, 변경 파일, ahead/behind 요약
- stage / unstage / commit 최소 버전
- push / pull / branch 전환 최소 버전
- PR/check 상태 read-only 요약
- 이 작업들을 기존 세션/리뷰 화면과 자연스럽게 연결하는 진입점

성공 기준:

- "검토만 하고 결국 데스크톱으로 가야 하는 상황" 감소
- 세션 종료 전 완료 가능한 작업 범위 증가
- 모바일에서 짧은 승인/수정 업무 처리 가능

우선순위:
`P0`

### WS3. Remote Operations And Orchestration

문제 정의:
현재 원격 개발 운영 액션이 존재하더라도 제품 기능으로 묶여 보이지 않는다.

핵심 질문:
작은 화면에서도 반복적인 원격 운영 작업을 셸 없이 빠르게 수행할 수 있는가?

필수 산출물:

- `Project Actions` 레이어
- 자주 쓰는 명령 실행 진입점
- dev server / service / background job 상태 카드
- 최근 URL 또는 포트 포워딩 관련 액션
- session search, worktree badge, context 강화
- 장시간 세션을 위한 로딩/탐색 개선

성공 기준:

- 반복 명령을 직접 입력해야 하는 빈도 감소
- 세션 수와 프로젝트 수가 늘어도 탐색 피로가 크지 않음
- 원격 운영 작업이 "대화 밖"의 제품 기능으로 인지됨

우선순위:
`P1`

### WS4. Mobile-Native Interaction

문제 정의:
현재 모바일 고유 가치는 재진입 편의에 머무르고, 입력 비용 절감과 접근성 확장은 약하다.

핵심 질문:
사용자가 이동 중이거나 손이 자유롭지 않은 상태에서도 핵심 작업을 수행할 수 있는가?

필수 산출물:

- voice prompt input
- 이미지/스크린샷 첨부의 빠른 진입
- notification inbox 기반 triage
- 한 손 사용을 고려한 compact action model
- 접근성 및 향후 RTL 대응을 고려한 설계 기준

성공 기준:

- 짧은 확인/승인/질문 응답 흐름이 빨라짐
- 텍스트 입력 부담이 줄어듦
- 모바일 전용 가치가 "다시 들어오기 쉬움"을 넘어섬

우선순위:
`P1`

### WS5. Packaging, Trust, And Surface Strategy

문제 정의:
우리 제품은 구현 속도 대비 외부에서 제품으로 읽히는 힘이 약하다.

핵심 질문:
처음 보는 사용자가 README와 릴리즈만 보고도 "왜 이 제품을 써야 하는지" 이해할 수 있는가?

필수 산출물:

- 사용자 가치 중심 README 재작성
- 설치/원격 사용/핵심 시나리오 스크린샷 또는 GIF
- 릴리즈 노트의 제품 언어화
- stable / experimental 구분이 있는 공개 로드맵
- 웹/PWA 또는 continuity 전략의 방향성 문서

성공 기준:

- README가 기술 노트가 아니라 제품 소개로 읽힘
- 외부 사용자가 첫 진입 경로를 쉽게 이해함
- 구현 강점이 시장 신뢰 신호로 번역됨

우선순위:
`P1/P2`

## 6. 추천 실행 순서

### Phase 1. 연결 성공률 개선

먼저 해결할 것은 WS1이다.  
이 단계의 목표는 `설치 후 첫 성공 경험`을 제품이 보장하는 것이다.

추천 범위:

- QR / deep link 연결
- 연결 진단 체크리스트
- 신뢰 UI
- 프로필 import/export

### Phase 2. 완료 루프 최소 버전

다음은 WS2다.  
이 단계의 목표는 `앱 안에서 끝낼 수 있는 작업`을 늘리는 것이다.

추천 범위:

- 브랜치/변경 파일 요약
- stage / commit / push
- PR/check read-only 요약

### Phase 3. 원격 운영과 모바일 차별화

그 다음은 WS3와 WS4를 묶는다.  
이 단계의 목표는 `모바일 원격 작업이 실제로 더 편하다`는 체감을 만드는 것이다.

추천 범위:

- Project Actions
- background/service visibility
- voice input
- triage 중심 액션 모델

### Phase 4. 패키징과 표면 확장

마지막은 WS5다.  
이 단계의 목표는 이미 만든 제품 가치를 외부 채택으로 연결하는 것이다.

추천 범위:

- README 개편
- 데모 자산 정리
- 로드맵 공개
- continuity 전략 문서화

## 7. 바로 착수할 작업 백로그

아래 항목은 이 문서를 기준으로 가장 먼저 쪼개기 좋은 구현 단위다.

1. 연결 프로필 import 스키마 정의
2. QR / deep link로 연결 프로필을 여는 진입점 추가
3. 연결 진단 결과 모델과 UI 설계
4. 현재 서버 / 프로젝트 / 세션을 보여주는 persistent context bar 설계
5. 저장소 상태 요약 모델 정의
6. stage / commit / push 최소 액션 플로우 설계
7. PR/check 상태 read-only 카드 설계
8. Project Actions 진입점과 액션 목록 정의
9. voice input 및 notification triage의 제품 요구사항 정의
10. README 개편 초안 작성

## 8. 하지 말아야 할 것

이 문서를 기준으로 당장은 아래를 핵심 목표로 잡지 않는다.

- 경쟁사 전체 기능 집합 복제
- 데스크톱/IDE 생태계 확장을 먼저 추진
- 대규모 테마/커뮤니티 표면 투자
- 제품 방향이 정리되기 전의 광범위한 UI 리브랜딩

우선은 `첫 연결`, `앱 안에서의 완료`, `모바일 원격 차별화`에 집중해야 한다.

## 9. 이후 문서 운영 원칙

앞으로 새 작업 문서나 구현 계획은 가능하면 아래 방식으로 이 문서에 매핑한다.

- 기능 제안은 `WS1`부터 `WS5` 중 하나에 귀속한다.
- 신규 작업은 가능하면 `Phase 1`부터 `Phase 4` 중 어느 단계인지 명시한다.
- 경쟁사 비교는 더 추가하더라도 최종 우선순위는 이 문서를 기준으로 재정렬한다.

즉, 이후 세부 설계 문서는 늘어날 수 있어도 `무엇을 먼저 할 것인가`의 기준은 이 문서를 우선한다.

## 10. 원문 출처

- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/competitive-analysis-codenomad-2026-03-31.md`
- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/openchamber-pm-gap-analysis.md`
