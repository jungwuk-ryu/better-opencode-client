# 실행 리스크 로그

작성일: 2026-03-31  
범위: Phase 1 ~ Phase 4 완료 기준의 잔여 리스크 정리

## 리스크 테이블

| ID | 리스크 | 영향 | 현재 대응 | 다음 확인 |
| --- | --- | --- | --- | --- |
| R-01 | iOS / Android 실기기 deep link 동작 편차 | 첫 연결 진입 실패 가능성 | custom scheme와 route parsing, import tests까지 반영 | 실제 디바이스에서 링크와 QR 열기 확인 |
| R-02 | shared import payload 만료 정책 운영 미정 | 오래된 링크가 혼란을 줄 수 있음 | validator가 expiry를 강제하고 시트가 검증 이슈를 노출 | 문서에 만료 정책 예시 추가 여부 검토 |
| R-03 | Git sheet는 최소 루프만 지원 | 고급 저장소 작업은 앱 안에서 미완결 | terminal fallback을 명시적으로 제공 | 실제 사용자 피드백으로 지원 범위 확대 판단 |
| R-04 | PR/check는 읽기 전용 | GitHub write loop 기대와 차이 발생 가능 | README와 roadmap에서 범위를 분리 | write action 필요성이 실제로 반복되는지 관찰 |
| R-05 | voice input은 기기 권한과 플랫폼 상태에 의존 | 일부 기기에서 시작 실패 가능 | 권한 문구와 실패 메시지를 제공 | 지원 문서에 권한 트러블슈팅 보강 |
| R-06 | demo assets는 storyboard 기반 | 실기기 캡처 기대와 차이가 있을 수 있음 | shot list와 storyboard를 함께 제공 | 공개 직전 live capture로 교체 가능성 확인 |

## 메모

- 현재 남은 리스크는 주로 운영 검증과 공개 패키징의 정교화 영역이다.
- 핵심 구현 결함은 `flutter analyze`와 대상 테스트 통과 기준에서 닫았다.
