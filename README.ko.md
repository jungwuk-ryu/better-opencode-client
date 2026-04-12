# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC 앱 아이콘" width="112">
</p>

책상 앞에 붙어 있지 않아도 OpenCode를 원격으로 사용하세요.

BOC는 iOS, Android, macOS, Windows에서 OpenCode를 원격으로 사용할 수 있도록 만든 크로스 플랫폼 Flutter 클라이언트입니다. OpenCode `1.4.3` 호환성을 기준으로 설계되었고, 메인 워크스테이션을 떠나 있을 때 실제로 필요한 일에 집중합니다: 서버 연결, 워크스페이스 재개, 세션 추적, 요청 응답, 컨텍스트 확인, 그리고 필요할 때 shell 명령 실행.

넓은 화면을 가지고 계신가요?

![BOC 멀티 패널 워크스페이스](assets/readme/multi-pane.png)

BOC는 세션 모니터링, Review, 파일, 컨텍스트, shell 출력, 병렬 워크스페이스 활동을 한눈에 보는 멀티 패널 커맨드 센터로 확장될 수 있습니다.

## 왜 BOC인가요

- **원격 우선 워크플로우**: OpenCode 서버를 저장하고 연결 상태를 확인한 뒤, 필요한 워크스페이스로 빠르게 돌아갑니다.
- **모바일 네이티브 조작**: 터치 친화적인 내비게이션, compact 레이아웃, 음성 입력, 파일 첨부, 알림, 한 손 조작을 제공합니다.
- **데스크톱급 워크스페이스**: 넓은 화면에서는 split pane, side panel, 세션 목록, Review 화면, 컨텍스트 상세 정보를 답답한 모바일 화면처럼 보이지 않게 제공합니다.
- **실시간 작업 피드백**: 작업이 실행되는 동안 shell 출력, 대기 중인 질문, 권한 요청, todos, 컨텍스트 사용량, 세션 활동을 계속 볼 수 있습니다.
- **예상 가능한 서버 관리**: 서버 항목을 쉽게 훑어보고, 새로고침하고, 수정하고, 삭제하고, 다시 연결할 수 있습니다.

## 핵심 기능

- 간단한 홈 화면에서 여러 원격 OpenCode 서버를 관리합니다.
- 워크스페이스에 들어가기 전에 서버 상태와 호환성을 probe합니다.
- 최근 프롬프트와 활성 child session을 포함해 프로젝트와 세션을 탐색합니다.
- slash commands, 첨부 파일, 모델 선택, reasoning 제어로 OpenCode 세션과 대화합니다.
- 대화 위치를 잃지 않고 대기 중인 질문과 권한 요청에 응답합니다.
- 전용 패널에서 컨텍스트 사용량, 파일, review diff, inbox 항목, todos, shell 활동을 확인합니다.
- 안내형 UI만으로 부족할 때 terminal tab을 실행합니다.
- 휴대폰, 태블릿, 노트북, 데스크톱 화면에 맞게 적응형 레이아웃을 사용합니다.

## 호환성

BOC는 OpenCode `1.4.3`을 대상으로 합니다. 현재 릴리스 준비 검증은 연결 probe, 워크스페이스/세션 로딩, 채팅, shell 및 terminal 흐름, 대기 중인 질문, 권한 요청, review/files/context 패널, 적응형 멀티 패널 레이아웃에 집중합니다.

지원 클라이언트 플랫폼:

- iOS
- Android
- macOS
- Windows

OpenCode 서버는 여전히 원격에서 실행됩니다. BOC는 그 서버에 연결하는 클라이언트 화면이며, 서버 자체를 대체하지 않습니다.

## 요구 사항

- `^3.11.1`과 호환되는 Dart SDK를 포함한 Flutter
- 접근 가능한 OpenCode `1.4.3` 서버
- 실행하려는 대상 플랫폼용 toolchain: iOS, Android, macOS, Windows

## 시작하기

```bash
flutter pub get
flutter run
```

그런 다음 홈 화면에서 OpenCode 서버를 추가하고, 연결 probe가 통과하는지 확인한 뒤 워크스페이스를 엽니다.

특정 디바이스에서 실행:

```bash
flutter devices
flutter run -d <device-id>
```

## 개발

프로젝트 CI와 같은 검사를 사용합니다:

```bash
flutter analyze
flutter test
```

## 프로젝트 상태

BOC는 릴리스 준비 중입니다. 현재 초점은 안정성, 예측 가능한 크로스 플랫폼 UX, 지원되는 OpenCode 버전과의 호환성입니다.
