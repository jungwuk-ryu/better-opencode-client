# Continuity 전략

작성일: 2026-03-31  
목적: 지금 당장 유지할 연속성과, 나중에 검토할 연속성을 구분한다.

## 1. 지금 하는 것

- custom scheme deep link로 연결 import를 연다.
- 저장된 서버 프로필을 재사용한다.
- 마지막 workspace 문맥을 복귀한다.
- 연결 상태와 project status를 home 화면에서 계속 보여준다.
- shared connection link를 복사해 재배포할 수 있게 한다.

## 2. 지금 하지 않는 것

- web/PWA 중심의 완전한 연속성 설계
- universal link를 주 경로로 승격
- 데스크톱과 모바일을 하나의 공용 shell로 통합
- 오프라인 편집과 동기화 충돌 해결을 먼저 약속

## 3. 현재 연속성의 기준

| 축 | 현재 구현 | 의미 |
| --- | --- | --- |
| 연결 진입 | `opencode-remote://connect?payload=...` | 외부에서 앱을 직접 열 수 있다 |
| 공유 | import payload 기반 프로필 공유 | 팀 내부 재사용이 쉽다 |
| 문맥 복귀 | 마지막 workspace와 세션 복구 | 다시 들어올 때 손실이 적다 |
| 상태 지속 | probe와 session status 표시 | 사용자가 현재 위치를 잃지 않는다 |

## 4. 나중에 볼 수 있는 것

- universal link
- web/PWA bridge
- desktop companion handoff
- 공유 링크의 만료/재발급 관리 강화

## 5. 판단 기준

- 사용자가 지금 더 자주 붙고 다시 돌아오는가?
- 그 흐름이 앱 안에서 실제로 더 빠른가?
- 유지보수 비용이 custom scheme보다 합리적인가?

위 세 질문에 명확히 답하지 못하면, continuity 확장은 뒤로 미룬다.

