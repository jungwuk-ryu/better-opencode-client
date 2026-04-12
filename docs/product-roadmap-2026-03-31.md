# 제품 로드맵

작성일: 2026-03-31  
목적: 현재 제품 방향을 `stable`과 `experimental`로 나눠 공개적으로 설명한다.

## 1. 로드맵 원칙

- 이미 동작하고 검증된 흐름은 `stable`로 둔다.
- 아직 탐색이 필요한 흐름은 `experimental`로 둔다.
- 사용자가 지금 당장 믿고 쓸 수 있는 것과, 나중에 커질 수 있는 것을 분리한다.

## 2. Stable

| 영역 | 현재 상태 | 사용자 가치 | 비고 |
| --- | --- | --- | --- |
| 서버 연결과 probe | 구현됨 | 첫 연결과 상태 확인이 가능하다 | connection home 기반 |
| 연결 import / deep link | 구현됨 | 공유 링크로 서버를 빠르게 열 수 있다 | custom scheme 지원 |
| 워크스페이스 복귀 | 구현됨 | 마지막 프로젝트와 세션 문맥을 이어간다 | route restore 포함 |
| git 최소 루프 | 구현됨 | stage, commit, push, branch 전환의 최소 경로가 있다 | read/write 혼합 |
| project actions | 구현됨 | 반복 액션을 한 시트에서 모아 쓴다 | mobile ops surface |
| inbox / triage | 구현됨 | 질문과 승인 요청을 한 곳에서 처리한다 | async 운영용 |
| quick attach | 구현됨 | 이미지, PDF, 텍스트 파일을 빠르게 붙인다 | 입력 비용 절감 |
| voice input | 구현됨 | 음성으로 prompt 입력을 시작할 수 있다 | 기기 권한 의존 |

## 3. Experimental

| 영역 | 현재 상태 | 앞으로 볼 가치 | 지금의 판단 |
| --- | --- | --- | --- |
| PR / check 쓰기 액션 | 탐색 대상 | 완전한 GitHub 루프 | 읽기 전용부터 안정화 |
| background job orchestration | 탐색 대상 | 장시간 작업 가시성 | 실제 사용 패턴을 더 모은다 |
| web / PWA continuity | 탐색 대상 | 브라우저와 모바일의 연결성 | 현재는 주 경로가 아님 |
| universal link 정교화 | 탐색 대상 | 외부 공유 진입 단순화 | custom scheme을 먼저 유지 |
| 고급 접근성 / RTL / 대형 텍스트 최적화 | 진행 후보 | 더 넓은 사용자 접근성 | 점진적 개선으로 간다 |

## 4. 가까운 다음 순서

1. 첫 연결 경험을 더 짧고 덜 헷갈리게 만든다.
2. git 루프를 더 안전하게 다듬는다.
3. project actions와 inbox를 반복 사용하기 좋게 정리한다.
4. README와 데모 자산을 외부 공개용으로 마무리한다.

## 5. 공개 문구의 기준

- 지금 가능한 기능은 지금 가능한 범위로만 적는다.
- 아직 실험인 기능은 `예정`이 아니라 `검토 중`으로 적는다.
- 안정성보다 과장이 앞서지 않게 한다.

