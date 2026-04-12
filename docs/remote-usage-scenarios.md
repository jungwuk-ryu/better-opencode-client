# 원격 사용 시나리오

작성일: 2026-03-31  
목적: 현재 제품이 실제로 풀어주는 원격 작업 흐름을 짧고 분명하게 정리한다.

## 1. 공통 시나리오 원칙

- 먼저 서버를 연결한다.
- 다음에 현재 상태를 확인한다.
- 그다음 필요한 작업을 최소 탭 수로 끝낸다.
- 작업이 앱 안에서 끝나지 않으면 terminal fallback으로 넘어간다.

## 2. 시나리오 표

| 시나리오 | 진입점 | 현재 UI 경로 | 성공 기준 | 비고 |
| --- | --- | --- | --- | --- |
| 연결 | 홈 화면, deep link | 서버 저장, probe 결과 확인, 연결 import 시트 | 서버 상태가 읽히고 워크스페이스로 진입 가능 | 첫 연결의 기준 경로 |
| triage | 워크스페이스 상단의 inbox | 질문, 승인, unread activity를 한곳에서 확인 | 질문/승인/읽지 않은 이벤트를 빠르게 처리 | 모바일 우선 흐름 |
| commit | 워크스페이스의 git sheet | 변경 파일 확인 후 commit composer 사용 | commit 메시지를 입력하고 저장소 상태를 다시 읽음 | stage 상태에 따라 다름 |
| push | git sheet | push 액션 실행 | remote로 push가 완료되고 상태가 갱신됨 | 실패 시 메시지 노출 |
| open link | project actions 또는 recent links | 링크를 열거나 복사 | 최근 열었던 원격 링크를 재사용 | 모바일 재진입 비용 절감 |

## 3. 연결 시나리오

1. 홈 화면에서 서버를 선택한다.
2. 상태 카드에서 probe 결과를 본다.
3. 연결 import 링크가 있으면 `Import Connection` 시트로 들어간다.
4. 검증을 통과한 서버를 저장한다.
5. 저장된 서버를 열고 워크스페이스로 이동한다.

## 4. triage 시나리오

1. 워크스페이스 상단에서 `Inbox`를 연다.
2. 질문, 승인, unread activity를 나눠 본다.
3. 필요한 세션을 다시 연다.
4. 권한 요청은 allow 또는 reject로 정리한다.

## 5. commit 시나리오

1. git sheet를 연다.
2. 변경 파일과 상태를 본다.
3. stage가 필요한 파일은 먼저 stage한다.
4. `Commit`을 눌러 제목과 본문을 입력한다.
5. 저장 후 상태를 다시 확인한다.

## 6. push 시나리오

1. commit 이후 git sheet를 다시 연다.
2. ahead/behind 정보를 읽는다.
3. `Push`를 실행한다.
4. 실패하면 terminal fallback으로 넘겨 원인을 더 자세히 본다.

## 7. open link 시나리오

1. project actions에서 recent link를 찾는다.
2. 링크를 다시 연다.
3. 필요하면 링크를 복사해서 외부로 전달한다.

## 8. 현재 문서가 의도적으로 다루지 않는 것

- issue 기반 세션 시작의 상세 절차
- PR 생성의 쓰기 액션
- 긴 백그라운드 잡 운영의 완전한 운영 콘솔
- web/PWA continuity

