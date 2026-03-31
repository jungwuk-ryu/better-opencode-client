# Phase 2 Git Loop Execution Pack

작성일: 2026-03-31  
대상 범위: `P2-01` ~ `P2-16`  
근거 코드: `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_git_models.dart`, `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_git_service.dart`, `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_git_sheet.dart`, `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart`

## 목표/종료조건 체크

Phase 2의 목표는 `판단 -> 수정 -> 커밋/푸시/PR 확인`의 최소 루프를 앱 안에서 끝내는 것이다. 현재 구현은 이 루프를 단일 `Git Workflow` 시트로 묶고, 상태 요약과 파일 단위 stage/unstage, commit, push, pull, branch 전환, PR/check 읽기 전용 요약, terminal fallback까지 연결한다.

종료조건 기준으로 보면 다음이 충족된다.

- 변경 파일과 저장소 상태를 앱 안에서 요약해서 본다.
- stage / commit / push / pull / branch 전환이 동작한다.
- PR/check 상태를 읽기 전용으로 보여준다.
- 실패 시 terminal fallback 경로가 명시되어 있다.

## 지원 범위

지원 범위는 보수적으로 잡았다. Git write action은 `stage`, `unstage`, `stage all`, `commit`, `pull --ff-only`, `push`, `switch branch`, `create branch`까지만 포함한다. GitHub write action은 넣지 않았고, PR/check는 `gh pr view --json ...`로 읽기 전용 요약만 표시한다.

실제 진입점은 `workspace_screen.dart`의 프로젝트 운영 표면과 `workspace_git_sheet.dart`의 전용 시트다. 저장소 상태는 `RepoStatusSnapshot` 모델로 정리되고, shell 실행은 `ProjectGitService`가 담당한다. 실패 시에는 시트를 닫고 terminal에서 직접 이어갈 수 있도록 안내하는 fallback 경로를 남겼다.

## 작업별 완료 근거 표

| ID | 완료 여부 | 상태 | 핵심 결과 | 근거 |
| --- | --- | --- | --- | --- |
| P2-01 | [x] | 완료 | 이번 Phase의 범위를 Git/GitHub 최소 완료 루프로 고정했다 | `workspace_git_sheet.dart`와 `project_git_service.dart`에 stage/commit/sync/branch/PR-check만 남기고 write-heavy GitHub 기능은 제외했다 |
| P2-02 | [x] | 완료 | 서버가 제공하는 상태/행동 경로를 기준으로 capability/endpoint를 확인했다 | `ProjectGitService.loadStatus()`는 `git status --short --branch`와 `gh pr view --json ...`를 쓰고, `loadBranches()`는 `git branch --format=...`를 사용한다 |
| P2-03 | [x] | 완료 | 저장소 상태를 모델로 구조화했다 | `RepoChangedFile`, `RepoBranchOption`, `RepoPullRequestSummary`, `RepoStatusSnapshot`, `RepoActionResult`를 `project_git_models.dart`에 정의했다 |
| P2-04 | [x] | 완료 | 저장소 상태 요약 카드 구조를 시트와 워크스페이스에 맞게 배치했다 | `workspace_screen.dart`의 프로젝트 요약 영역과 `workspace_git_sheet.dart`의 overview card가 branch, staged/unstaged, PR 요약을 노출한다 |
| P2-05 | [x] | 완료 | 현재 branch, 변경 수, 위험 상태를 한눈에 보이게 했다 | `RepoStatusSnapshot.stagedCount`, `unstagedCount`, `conflictedCount`, `untrackedCount`와 `workspace_screen.dart`의 요약 문구가 연결된다 |
| P2-06 | [x] | 완료 | 파일 단위 stage/unstage와 충돌 상태 처리를 위한 액션 모델을 만들었다 | `RepoChangedFile.statusLabel`과 `RepoChangedFile`의 staged/unstaged/conflicted/untracked 플래그가 UI와 서비스의 공통 기준이다 |
| P2-07 | [x] | 완료 | 변경 파일 목록에서 상태 전환을 지원했다 | `workspace_git_sheet.dart`에서 각 파일에 `stage`/`unstage` 버튼을 붙이고 `ProjectGitService.stageFile()`/`unstageFile()`을 호출한다 |
| P2-08 | [x] | 완료 | commit composer를 모바일 입력에 맞게 구성했다 | `_CommitComposerDialog`가 제목/본문 입력, validation, empty staged state를 처리한다 |
| P2-09 | [x] | 완료 | commit 실행과 결과 피드백을 연결했다 | `ProjectGitService.commit()`과 `workspace_git_sheet.dart`의 `_showCommitComposer()` / `_runAction()`이 성공·실패 메시지를 분기한다 |
| P2-10 | [x] | 완료 | push/pull 액션과 refresh 피드백을 연결했다 | `ProjectGitService.pull()`은 `git pull --ff-only`, `push()`는 `git push`를 실행하고 시트가 재조회된다 |
| P2-11 | [x] | 완료 | branch 전환/생성 UX를 구현했다 | `_BranchPickerSheet`와 `ProjectGitService.switchBranch()`/`createBranch()`가 branch list, switch, create를 처리한다 |
| P2-12 | [x] | 완료 | PR/check read model을 정의했다 | `RepoPullRequestSummary`가 PR 번호, 제목, URL, state, reviewDecision, head/base branch, check counts를 담는다 |
| P2-13 | [x] | 완료 | PR/check 요약 카드를 읽기 전용으로 보여준다 | `workspace_git_sheet.dart`의 `_RepoPullRequestCard`가 현재 branch에 연결된 PR과 check summary를 표시한다 |
| P2-14 | [x] | 완료 | workspace/review/terminal의 진입점을 단순화했다 | `workspace_screen.dart`의 프로젝트 운영 표면에서 `Git Workflow`와 terminal fallback 진입이 같이 보인다 |
| P2-15 | [x] | 완료 | 실패 시 안전한 fallback을 제공했다 | `WorkspaceGitSheet` 상단 설명과 액션 실패 처리에서 terminal로 넘겨서 수동 복구할 수 있게 했다 |
| P2-16 | [x] | 완료 | git loop를 테스트와 문서로 고정했다 | `test/features/projects/project_git_service_test.dart`가 status/branch/PR parser와 shell capture parser를 검증한다 |

## 테스트/제약

검증은 다음 기준으로 통과했다.

- `flutter analyze`
- `flutter test test/features/connection/connection_profile_import_test.dart test/features/projects/project_git_service_test.dart test/features/chat/prompt_attachment_service_test.dart`

제약도 명시한다.

- PR/check는 읽기 전용이다. 현재 구현은 `gh pr view --json ...`를 읽어서 요약만 보여주며, PR 생성이나 review write는 하지 않는다.
- destructive Git action은 포함하지 않았다. reset, revert, force push 같은 동작은 Phase 2 범위 밖으로 뺐다.
- terminal fallback은 자동 복구가 아니라 안전한 이탈 경로다. 앱 안의 write action이 실패해도 사용자가 shell에서 이어서 처리할 수 있도록 만든다.
- shell output 파싱은 `__BOC_EXIT__=` 마커를 기준으로 하므로, terminal command는 이 래핑 규칙을 전제로 한다.

추가로 확인한 구현 근거는 다음과 같다.

- 상태 파싱과 PR 요약 파싱: `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_git_service.dart`
- 상태/branch/PR 요약 모델: `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/projects/project_git_models.dart`
- 시트형 UI와 terminal fallback: `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_git_sheet.dart`
- 워크스페이스 진입점과 요약 카드: `/Users/jungwuk/Documents/works/opencode-mobile-remote/lib/src/features/web_parity/workspace_screen.dart`
- parser test: `/Users/jungwuk/Documents/works/opencode-mobile-remote/test/features/projects/project_git_service_test.dart`

