# 모바일 접근성 및 운영성 점검

작성일: 2026-03-31  
범위: Phase 3 `P3-18` 및 Ongoing QA 근거

## 점검 표

| 항목 | 현재 상태 | 근거 | 판정 |
| --- | --- | --- | --- |
| text scaling | 지원 | 앱 전역 text scaler와 compact density가 반영되어 있다 | 통과 |
| localized labels | 지원 | 주요 액션과 상태 라벨이 localization wrapper를 통해 노출된다 | 통과 |
| one-hand reachability | 지원 | inbox, project actions, voice, attachments가 상단과 composer 가까이에 배치된다 | 통과 |
| long-session fatigue | 지원 | inbox triage, project actions, git sheet, terminal fallback으로 반복 이동을 줄인다 | 통과 |
| attachment feedback | 지원 | 비지원 파일은 거절 메시지로 안내한다 | 통과 |
| voice fallback | 지원 | 음성 입력 실패 시 즉시 메시지를 보여 주고 텍스트 입력으로 복귀할 수 있다 | 통과 |
| large flow separation | 지원 | 큰 작업은 bottom sheet로 분리되어 작은 화면에서도 컨텍스트가 유지된다 | 통과 |
| RTL / broad i18n readiness | 부분 지원 | localized label 구조는 있으나 RTL 전용 시각 검수는 후속 실기기 검토가 필요하다 | 통과 with follow-up |

## 후속 확인 메모

- 실제 RTL 언어 전환과 실기기 text scale extremes는 공개 직전 한 번 더 점검한다.
- 현재 구조는 접근성 확장을 막지 않지만, 시각적 polish는 운영 검증에서 보완할 수 있다.
