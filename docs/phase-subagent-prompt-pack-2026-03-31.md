# Phase 병렬 작성용 프롬프트 팩

작성일: 2026-03-31  
대상 저장소: `/Users/jungwuk/Documents/works/opencode-mobile-remote`

이 문서는 `Phase 1`, `Phase 2`, `Phase 3`, `Phase 4`를 각각 별도 세션 + worktree + branch에서 진행하면서, 각 세션 안에서 다시 서브 에이전트를 병렬로 돌리기 위한 프롬프트 팩이다.

## 1. 권장 운영 방식

1. 각 Phase는 서로 다른 세션, worktree, branch에서 진행한다.
2. 각 Phase 세션은 `부모 세션` 1개와 `서브 에이전트` 4개로 운영한다.
3. 서브 에이전트는 절대 최종 Phase 문서를 직접 같이 수정하지 않는다.
4. 서브 에이전트는 각자 지정된 `draft 파일` 1개만 책임진다.
5. 부모 세션이 서브 에이전트 결과를 검토하고 최종 Phase 문서로 통합한다.

## 2. 공통 규칙

### 공통 읽기 문서

- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md`
- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md`

### 공통 작성 규칙

- 문서 언어는 한국어
- 표 중심 문서 작성
- 완료 여부는 `[x]`, `[ ]`
- 상태는 `완료`, `진행중`, `미착수`, `보류`
- 다른 Phase 범위를 새로 정의하지 말 것
- master 문서 `pm-phase-execution-plan-2026-03-31.md`는 수정하지 말 것
- 코드 수정하지 말 것
- 사용자나 다른 에이전트가 만든 변경을 되돌리지 말 것
- 추정이 필요한 부분은 반드시 `가정` 또는 `검증 필요`로 분리할 것

### 공통 충돌 방지 규칙

- 서브 에이전트는 자신이 소유한 draft 파일 외에는 수정하지 말 것
- 부모 세션만 최종 문서를 수정할 것
- draft 파일 경로는 서로 겹치지 않게 유지할 것

## 3. Phase 1

### 3.1 부모 세션 프롬프트

```text
현재 세션은 Phase 1 부모 세션입니다.
이 세션의 목표는 Phase 1 전용 실행 문서를 완성하는 것입니다.

작업 성격:
- 코드 수정이 아니라 실행용 문서 작성 작업
- 서브 에이전트를 병렬로 사용
- 최종 통합은 부모 세션인 당신이 담당

먼저 아래 문서를 읽으세요.
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-05-app-only-feature-plan.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-subagent-prompt-pack-2026-03-31.md

당신의 최종 산출물:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-1-connection-success-execution-plan.md

서브 에이전트용 draft 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/01-discovery-schema.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/02-qr-deeplink-import.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/03-diagnostic-trust-ui.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/04-qa-docs-release.md

당신이 할 일:
1. 공통 기준 문서를 읽고 Phase 1 범위를 재확인한다.
2. 서브 에이전트 4개를 병렬로 띄운다.
3. 각 서브 에이전트에게 아래 prompt pack의 Phase 1 전용 프롬프트를 그대로 사용하게 한다.
4. 서브 에이전트가 같은 파일을 수정하지 않도록 ownership을 엄격히 지킨다.
5. 당신은 최종 문서만 편집한다. 서브 에이전트 draft를 읽고 중복 제거, 구조 통합, ID 정규화, 종료 조건 정리를 수행한다.
6. 최종 문서는 master 문서의 Phase 1보다 훨씬 자세한 대형 실행 문서여야 하며, 최소 30개 이상의 작업 행을 포함해야 한다.
7. 문서에는 최소 아래 섹션이 있어야 한다.
   - 목적
   - 범위
   - 비범위
   - 사용자 가치
   - 종료 조건
   - 요약 대시보드
   - 세부 작업 테이블
   - 리스크/의존성
   - 오픈 질문
   - 바로 구현할 Top 10
8. 하위 작업 ID는 충돌 없이 일관적으로 정리한다.
9. 서브 에이전트 결과가 모이면 최종 문서에 통합하고 스스로 검토한다.

중요 제약:
- master 문서는 수정하지 말 것
- 다른 Phase 문서는 수정하지 말 것
- 코드 수정하지 말 것
- draft 파일을 통합한 뒤 최종 문서만 부모 세션이 완성할 것
- 서브 에이전트의 표현 차이는 부모 세션이 통일할 것

최종 검토 체크:
- Phase 1 목표가 “첫 연결 성공 경험 보장”으로 일관적인가
- QR/deep link, 진단 위저드, trust UI, import/export, QA/docs가 모두 포함되었는가
- 작업이 티켓으로 바로 쪼개질 정도로 충분히 구체적인가
```

### 3.2 서브 에이전트 A 프롬프트

```text
당신은 Phase 1 서브 에이전트 A입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/01-discovery-schema.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-05-app-only-feature-plan.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md

당신의 담당 범위:
- Discovery
- Funnel
- Requirements
- Schema
- Data model
- Validation baseline

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 Phase 1의 앞단 설계와 구조 정의를 초안으로 만든다.
- 최소 10개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 가정
  - 세부 작업 테이블
  - 리스크
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P1-DISC-01
  - P1-FUNNEL-01
  - P1-REQ-01
  - P1-SCHEMA-01
- 각 작업 테이블 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서인 phase-1-connection-success-execution-plan.md는 수정하지 말 것
- 다른 draft 파일도 수정하지 말 것
- Phase 1 범위 밖 작업을 새로 만들지 말 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 3.3 서브 에이전트 B 프롬프트

```text
당신은 Phase 1 서브 에이전트 B입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/02-qr-deeplink-import.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- QR 연결 UX
- Deep link 연결 UX
- Import/export flow
- Payload parsing
- Duplicate handling
- Shared profile flow

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 연결 진입과 프로필 이동 경로를 초안으로 만든다.
- 최소 8개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - UX 원칙
  - 세부 작업 테이블
  - 예외/실패 시나리오
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P1-QR-01
  - P1-LINK-01
  - P1-IMPORT-01
- 각 작업 테이블 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서를 수정하지 말 것
- 다른 draft 파일 수정 금지
- 보안, 만료 링크, 잘못된 payload, 중복 프로필 시나리오를 반드시 포함할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 3.4 서브 에이전트 C 프롬프트

```text
당신은 Phase 1 서브 에이전트 C입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/03-diagnostic-trust-ui.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md

당신의 담당 범위:
- Connection diagnostic wizard
- Network/TLS/auth/capability 분해
- Failure recovery action
- Persistent context bar
- Trust UI
- Verified connection metadata

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 진단/복구/trust UI 영역 초안을 만든다.
- 최소 8개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 진단 축 정의
  - 세부 작업 테이블
  - 사용자 메시지 원칙
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P1-DIAG-01
  - P1-RECOVERY-01
  - P1-TRUST-01
- 각 작업 테이블 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서를 수정하지 말 것
- 다른 draft 파일 수정 금지
- 진단 결과 문구는 사용자가 이해 가능한 제품 언어를 기준으로 적을 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 3.5 서브 에이전트 D 프롬프트

```text
당신은 Phase 1 서브 에이전트 D입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-1/04-qa-docs-release.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md

당신의 담당 범위:
- Test strategy
- QA matrix
- Docs
- Onboarding copy
- Release note
- Exit criteria verification

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 품질/문서/출시 준비 영역 초안을 만든다.
- 최소 6개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - QA 관점 핵심 체크포인트
  - 세부 작업 테이블
  - 출시 전 체크리스트
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P1-QA-01
  - P1-DOC-01
  - P1-REL-01
- 각 작업 테이블 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서를 수정하지 말 것
- 다른 draft 파일 수정 금지
- QA는 happy path가 아니라 실패 경로까지 포함할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

## 4. Phase 2

### 4.1 부모 세션 프롬프트

```text
현재 세션은 Phase 2 부모 세션입니다.
이 세션의 목표는 Phase 2 전용 실행 문서를 완성하는 것입니다.

작업 성격:
- 코드 수정이 아니라 실행용 문서 작성 작업
- 서브 에이전트를 병렬로 사용
- 최종 통합은 부모 세션인 당신이 담당

먼저 아래 문서를 읽으세요.
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-subagent-prompt-pack-2026-03-31.md

당신의 최종 산출물:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-2-completion-loop-execution-plan.md

서브 에이전트용 draft 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/01-scope-capability-repo-model.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/02-stage-commit-branch.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/03-pr-check-fallback.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/04-qa-docs-errors.md

당신이 할 일:
1. Phase 2 범위를 “앱 안에서 최소 완료 루프 닫기”로 고정한다.
2. 서브 에이전트 4개를 병렬로 띄운다.
3. 각 서브 에이전트가 서로 다른 draft 파일만 수정하도록 ownership을 엄격히 분리한다.
4. 당신은 최종 문서만 편집한다.
5. 최종 문서는 최소 30개 이상의 작업 행을 포함해야 한다.
6. 아래 섹션이 반드시 들어가야 한다.
   - 목적
   - 범위
   - 비범위
   - 성공 지표
   - 종료 조건
   - 요약 대시보드
   - 세부 작업 테이블
   - fallback 전략
   - 에러/실패 UX
   - 리스크/오픈 질문
   - MVP 범위
   - 차기 확장 범위
   - 바로 구현할 Top 10
7. PR 생성 같은 확장 범위가 애매하면 `MVP`, `후속 확장`, `검증 필요`로 분리한다.
8. 서브 에이전트 결과를 통합하면서 표현과 용어를 통일한다.

중요 제약:
- master 문서 수정 금지
- 다른 Phase 문서 수정 금지
- 코드 수정 금지
- completion loop의 범위를 과도하게 넓히지 말 것

최종 검토 체크:
- 저장소 상태, stage/commit/push/branch, PR/check read-only, fallback이 모두 포함되었는가
- “모바일에서 끝낼 수 있는 최소 루프”가 문서의 중심인가
- 실패 UX와 안전 장치가 빠지지 않았는가
```

### 4.2 서브 에이전트 A 프롬프트

```text
당신은 Phase 2 서브 에이전트 A입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/01-scope-capability-repo-model.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- Scope definition
- Capability audit
- Endpoint audit
- Repo status read model
- Branch/ahead/behind/changed files/staged count model

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 Phase 2의 범위와 데이터 모델 기반 초안을 만든다.
- 최소 8개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 가정
  - 세부 작업 테이블
  - capability 관련 오픈 질문
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P2-SCOPE-01
  - P2-CAP-01
  - P2-REPO-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 범위가 불명확한 GitHub 기능은 가정 또는 검증 필요로 분리할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 4.3 서브 에이전트 B 프롬프트

```text
당신은 Phase 2 서브 에이전트 B입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/02-stage-commit-branch.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- Repo summary UI
- Stage / unstage
- Commit composer
- Push / pull
- Branch switch / create

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 실행 루프의 핵심 액션 영역 초안을 만든다.
- 최소 10개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - UX 원칙
  - 세부 작업 테이블
  - 위험 액션 안전장치
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P2-SUMMARY-01
  - P2-STAGE-01
  - P2-COMMIT-01
  - P2-SYNC-01
  - P2-BRANCH-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- destructive하거나 혼란을 줄 수 있는 액션은 반드시 확인/실패 UX까지 포함할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 4.4 서브 에이전트 C 프롬프트

```text
당신은 Phase 2 서브 에이전트 C입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/03-pr-check-fallback.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- PR/check read-only surface
- Workspace/review navigation linkage
- Safe fallback to terminal
- Error recovery path

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 read-only GitHub surface와 fallback 전략 초안을 만든다.
- 최소 7개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - read-only 범위 정의
  - 세부 작업 테이블
  - fallback 전략
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P2-PR-01
  - P2-CHECK-01
  - P2-NAV-01
  - P2-FALLBACK-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 지원 여부가 불명확한 기능은 명확히 `검증 필요`로 적을 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 4.5 서브 에이전트 D 프롬프트

```text
당신은 Phase 2 서브 에이전트 D입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-2/04-qa-docs-errors.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md

당신의 담당 범위:
- Error cases
- QA
- Test strategy
- Docs
- Release gating

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 실패 경로와 검증 계획 초안을 만든다.
- 최소 6개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 주요 실패 시나리오
  - 세부 작업 테이블
  - 출시 게이트
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P2-ERR-01
  - P2-QA-01
  - P2-DOC-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- happy path보다 실패 경로와 품질 기준을 우선 명시할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

## 5. Phase 3

### 5.1 부모 세션 프롬프트

```text
현재 세션은 Phase 3 부모 세션입니다.
이 세션의 목표는 Phase 3 전용 실행 문서를 완성하는 것입니다.

작업 성격:
- 코드 수정이 아니라 실행용 문서 작성 작업
- 서브 에이전트를 병렬로 사용
- 최종 통합은 부모 세션인 당신이 담당

먼저 아래 문서를 읽으세요.
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-05-app-only-feature-plan.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-subagent-prompt-pack-2026-03-31.md

당신의 최종 산출물:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-3-remote-ops-mobile-execution-plan.md

서브 에이전트용 draft 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/01-ops-actions.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/02-services-search-context.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/03-voice-attach-triage.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/04-a11y-performance-qa.md

당신이 할 일:
1. Phase 3 범위를 “원격 운영성 + 모바일 고유 입력/상호작용 강화”로 고정한다.
2. 서브 에이전트 4개를 병렬로 띄운다.
3. 각 서브 에이전트가 서로 다른 draft 파일만 수정하도록 ownership을 엄격히 분리한다.
4. 당신은 최종 문서만 편집한다.
5. 최종 문서는 최소 35개 이상의 작업 행을 포함해야 한다.
6. 아래 섹션이 반드시 들어가야 한다.
   - 목적
   - 범위
   - 비범위
   - 사용자 가치 요약
   - 종료 조건
   - 요약 대시보드
   - 세부 작업 테이블
   - 모바일 차별화 포인트
   - quick wins
   - 중간 난이도
   - 고위험/고효과
   - 리스크/오픈 질문
7. 경쟁사 기능을 그대로 복제하는 문서가 아니라, 모바일 원격 제품 차별화 기준서가 되도록 통합한다.
8. 서브 에이전트 결과를 통합하면서 용어와 우선순위를 정리한다.

중요 제약:
- master 문서 수정 금지
- 다른 Phase 문서 수정 금지
- 코드 수정 금지
- 운영성 강화와 모바일 차별화가 균형 있게 드러나야 한다

최종 검토 체크:
- Project Actions, service/job visibility, session search/context, voice/attach/triage, a11y/performance가 모두 포함되었는가
- 장시간 사용 시 피로 감소와 모바일 입력 비용 절감이 분명히 드러나는가
```

### 5.2 서브 에이전트 A 프롬프트

```text
당신은 Phase 3 서브 에이전트 A입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/01-ops-actions.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- Remote ops inventory
- Project Actions IA
- Action model
- Entry UI
- Saved command actions
- Recent URL actions
- Port preset baseline

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 운영 액션 계층 초안을 만든다.
- 최소 10개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 운영 액션 설계 원칙
  - 세부 작업 테이블
  - 사용 빈도 기준 우선순위
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P3-OPS-01
  - P3-ACTION-01
  - P3-CMD-01
  - P3-URL-01
  - P3-PORT-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 반복 입력 감소와 모바일 한 탭 액션에 초점을 맞출 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 5.3 서브 에이전트 B 프롬프트

```text
당신은 Phase 3 서브 에이전트 B입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/02-services-search-context.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- Dev server/service status
- Background job/process visibility
- Session search
- Worktree context
- Long-session navigation UX

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 운영성 강화 영역 초안을 만든다.
- 최소 9개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 운영성 강화 포인트
  - 세부 작업 테이블
  - 헤비 유저 관점 메모
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P3-SVC-01
  - P3-JOB-01
  - P3-SEARCH-01
  - P3-CONTEXT-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 장시간 사용과 다중 세션 탐색 피로 감소를 핵심 기준으로 둘 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 5.4 서브 에이전트 C 프롬프트

```text
당신은 Phase 3 서브 에이전트 C입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/03-voice-attach-triage.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- Voice input requirements
- Voice input MVP
- Quick attach
- Notification inbox
- Triage flow

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 모바일 입력 보조와 async triage 영역 초안을 만든다.
- 최소 8개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 입력 비용 절감 관점 메모
  - 세부 작업 테이블
  - 플랫폼/권한 관련 가정
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P3-VOICE-01
  - P3-ATTACH-01
  - P3-TRIAGE-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 플랫폼 제약, 권한, 실패 케이스는 반드시 분리해서 적을 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 5.5 서브 에이전트 D 프롬프트

```text
당신은 Phase 3 서브 에이전트 D입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-3/04-a11y-performance-qa.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/mission-06-scenario-review.md

당신의 담당 범위:
- One-hand interaction
- Accessibility
- RTL readiness
- Long-session performance
- QA and release checks

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 품질/접근성/성능 영역 초안을 만든다.
- 최소 8개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 품질 축 정의
  - 세부 작업 테이블
  - 실험/탐색 필요 항목
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P3-ONEHAND-01
  - P3-A11Y-01
  - P3-RTL-01
  - P3-PERF-01
  - P3-QA-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- UI polish가 아니라 실제 사용 품질 게이트를 중심으로 적을 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

## 6. Phase 4

### 6.1 부모 세션 프롬프트

```text
현재 세션은 Phase 4 부모 세션입니다.
이 세션의 목표는 Phase 4 전용 실행 문서를 완성하는 것입니다.

작업 성격:
- 코드 수정이 아니라 실행용 문서 작성 작업
- 서브 에이전트를 병렬로 사용
- 최종 통합은 부모 세션인 당신이 담당

먼저 아래 문서를 읽으세요.
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/competitive-analysis-codenomad-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/openchamber-pm-gap-analysis.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-subagent-prompt-pack-2026-03-31.md

당신의 최종 산출물:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-4-packaging-trust-execution-plan.md

서브 에이전트용 draft 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/01-positioning-messaging.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/02-readme-quickstart-docs.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/03-demo-roadmap-continuity.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/04-validation-publish-feedback.md

당신이 할 일:
1. Phase 4 범위를 “패키징, 신뢰, 외부 채택 강화”로 고정한다.
2. 서브 에이전트 4개를 병렬로 띄운다.
3. 각 서브 에이전트가 서로 다른 draft 파일만 수정하도록 ownership을 엄격히 분리한다.
4. 당신은 최종 문서만 편집한다.
5. 최종 문서는 최소 25개 이상의 작업 행을 포함해야 한다.
6. 아래 섹션이 반드시 들어가야 한다.
   - 목적
   - 범위
   - 비범위
   - 외부 사용자 관점 성공 기준
   - 종료 조건
   - 요약 대시보드
   - 세부 작업 테이블
   - README 개편 전후 차이
   - 첫인상 체크리스트
   - 출시 준비 최소 패키지
   - 출시 후 1차 피드백 수집 계획
   - 리스크/오픈 질문
7. 문서는 기술 설명보다 제품 채택 관점이 앞서야 한다.
8. continuity 전략은 탐색 범위로 다루되, 현재 즉시 구현 범위를 과도하게 넓히지 않는다.

중요 제약:
- master 문서 수정 금지
- 다른 Phase 문서 수정 금지
- 코드 수정 금지
- README, quickstart, demo assets, roadmap이 하나의 패키지로 연결되도록 통합할 것

최종 검토 체크:
- 외부 사용자가 왜 이 제품을 써야 하는지가 드러나는가
- 공개 직전 체크리스트로 쓸 수 있을 정도로 구체적인가
```

### 6.2 서브 에이전트 A 프롬프트

```text
당신은 Phase 4 서브 에이전트 A입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/01-positioning-messaging.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/competitive-analysis-codenomad-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/openchamber-pm-gap-analysis.md

당신의 담당 범위:
- Positioning
- Messaging
- Audience definition
- Core value proposition
- Product language baseline

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 제품 메시지와 포지셔닝 영역 초안을 만든다.
- 최소 6개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 핵심 메시지 가설
  - 세부 작업 테이블
  - 제품 언어 원칙
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P4-MSG-01
  - P4-POS-01
  - P4-AUD-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 기술 설명이 아니라 채택 메시지를 중심으로 적을 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 6.3 서브 에이전트 B 프롬프트

```text
당신은 Phase 4 서브 에이전트 B입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/02-readme-quickstart-docs.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- README IA
- Quickstart
- Docs structure
- First-run doc journey

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 README와 문서 체계 초안을 만든다.
- 최소 7개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - README 개편 전후 차이 메모
  - 세부 작업 테이블
  - 첫 연결 문서 여정
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P4-README-01
  - P4-START-01
  - P4-DOC-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 문서 정보 구조는 외부 신규 사용자의 첫인상 기준으로 설계할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 6.4 서브 에이전트 C 프롬프트

```text
당신은 Phase 4 서브 에이전트 C입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/03-demo-roadmap-continuity.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/competitive-analysis-codenomad-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/openchamber-pm-gap-analysis.md

당신의 담당 범위:
- Demo assets
- Scenario guide
- Stable vs experimental roadmap
- Continuity strategy memo

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 시연 자산과 공개 계획 영역 초안을 만든다.
- 최소 7개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 외부 시연 관점 메모
  - 세부 작업 테이블
  - continuity 관련 검토 범위
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P4-DEMO-01
  - P4-SCENARIO-01
  - P4-ROADMAP-01
  - P4-CONT-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- continuity는 검토 범위로 다루고 즉시 구현 범위와 분리할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

### 6.5 서브 에이전트 D 프롬프트

```text
당신은 Phase 4 서브 에이전트 D입니다.
당신은 혼자 작업하는 것이 아니며, 다른 서브 에이전트들도 동시에 작업 중입니다.
다른 사람이 만든 변경을 되돌리거나 건드리지 말고, 당신에게 할당된 파일만 수정하세요.

당신의 단독 소유 파일:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/_drafts/phase-4/04-validation-publish-feedback.md

먼저 읽을 문서:
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-competitive-gap-synthesis-2026-03-31.md
- /Users/jungwuk/Documents/works/opencode-mobile-remote/docs/pm-phase-execution-plan-2026-03-31.md

당신의 담당 범위:
- External validation
- Publish checklist
- Feedback/support entry
- Post-launch review loop

작성 목표:
- 부모 세션이 최종 통합할 수 있도록 공개 검증과 피드백 회수 영역 초안을 만든다.
- 최소 6개 이상의 작업 행을 포함한다.

문서 요구사항:
- 한국어
- 표 중심
- 아래 섹션 포함
  - 담당 범위 요약
  - 첫인상 검증 관점 메모
  - 세부 작업 테이블
  - 출시 후 1차 피드백 계획
  - 부모 세션에 전달할 통합 메모
- 작업 ID prefix 예시:
  - P4-VALID-01
  - P4-PUBLISH-01
  - P4-FEEDBACK-01
- 컬럼:
  - ID
  - 완료 여부
  - 상태
  - 작업
  - 세부 범위
  - 선행
  - 산출물
  - 검증
  - 비고

중요 제약:
- 최종 문서 수정 금지
- 다른 draft 파일 수정 금지
- 공개 이후 피드백 회수까지 포함해 닫힌 루프로 설계할 것

최종 응답에는 변경한 파일 경로만 짧게 적으세요.
```

## 7. 부모 세션용 통합 후 검토 프롬프트

아래 프롬프트는 각 Phase 부모 세션이 서브 에이전트 결과를 다 받은 뒤, 최종 문서를 마감할 때 공통으로 사용할 수 있다.

```text
이제 모든 서브 에이전트 결과가 도착했다.
당신은 부모 세션으로서 아래 작업을 수행하라.

1. 모든 draft 파일을 읽고 중복 작업과 표현 차이를 정리하라.
2. 작업 ID 체계를 정규화하라.
3. Phase 목표와 직접 관련 없는 항목은 제거하거나 `후속 검토`로 내리라.
4. 최종 문서의 구조를 일관되게 맞춰라.
5. 완료 여부, 상태, 선행, 산출물, 검증, 비고 컬럼이 모두 들어갔는지 확인하라.
6. 각 하위 묶음이 종료 조건과 연결되는지 확인하라.
7. 마지막에 아래 항목을 포함하라.
   - 요약 대시보드
   - 리스크/의존성
   - 오픈 질문
   - 바로 구현할 Top 10
8. draft 문서의 문체와 용어를 통일하라.
9. 최종 문서만 수정하고, master 문서는 수정하지 말라.
10. 최종적으로 스스로 리뷰해서 “바로 티켓으로 쪼개도 되는 수준인지” 확인하라.
```

## 8. 권장 브랜치 예시

- `codex/phase1-plan`
- `codex/phase2-plan`
- `codex/phase3-plan`
- `codex/phase4-plan`

## 9. 권장 산출 파일 예시

- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-1-connection-success-execution-plan.md`
- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-2-completion-loop-execution-plan.md`
- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-3-remote-ops-mobile-execution-plan.md`
- `/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/phase-4-packaging-trust-execution-plan.md`
