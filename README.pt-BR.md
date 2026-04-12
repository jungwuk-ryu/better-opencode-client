# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Ícone do app BOC" width="112">
</p>

OpenCode remoto, sem ficar preso à mesa.

BOC é um cliente Flutter multiplataforma para usar OpenCode remotamente no iOS, Android, macOS e Windows. Ele foi projetado em torno da compatibilidade com OpenCode `1.4.3` e foca no trabalho que você realmente precisa quando está longe da sua estação principal: conectar a um servidor, retomar um workspace, acompanhar sessions, responder solicitações, inspecionar contexto e executar um comando shell quando necessário.

Tem uma tela ampla?

![Workspace multipainel do BOC](assets/readme/multi-pane.png)

BOC pode se expandir em um centro de comando multipainel para monitoramento de sessions, Review, arquivos, contexto, saída shell e atividade paralela do workspace.

## Por que BOC

- **Fluxo remote-first**: salve servidores OpenCode, verifique o status de conexão e volte rapidamente ao workspace certo.
- **Controles nativos para mobile**: navegação amigável ao toque, layouts compactos, entrada por voz, anexos, notificações e ações com uma mão.
- **Workspace de nível desktop**: telas amplas recebem split panes, side panels, listas de sessions, superfícies de Review e detalhes de contexto sem virar uma visualização mobile apertada.
- **Feedback operacional ao vivo**: saída shell, perguntas pendentes, permissões, todos, uso de contexto e atividade de session permanecem visíveis enquanto o trabalho roda.
- **Gerenciamento previsível de servidores**: entradas de servidor são fáceis de examinar, atualizar, editar, excluir e reconectar.

## Principais recursos

- Gerencie vários servidores OpenCode remotos a partir de uma tela inicial simples.
- Verifique saúde e compatibilidade do servidor antes de entrar em um workspace.
- Navegue por projetos e sessions, incluindo prompts recentes e child sessions ativas.
- Converse com sessions OpenCode usando slash commands, anexos, seleção de modelo e controles de reasoning.
- Responda perguntas pendentes e solicitações de permissão sem perder seu lugar na conversa.
- Inspecione uso de contexto, arquivos, review diffs, itens de inbox, todos e atividade shell em painéis dedicados.
- Execute abas de terminal quando uma UI guiada não for suficiente.
- Use layouts adaptativos em telefones, tablets, notebooks e monitores desktop.

## Compatibilidade

BOC mira OpenCode `1.4.3`. A validação atual de preparação de release foca em connection probing, carregamento de workspace/session, chat, fluxos shell e terminal, perguntas pendentes, solicitações de permissão, painéis review/files/context e layouts multipainel adaptativos.

Plataformas cliente suportadas:

- iOS
- Android
- macOS
- Windows

O servidor OpenCode continua rodando remotamente; BOC é a superfície cliente para conectar a ele, não um substituto para o servidor em si.

## Requisitos

- Flutter com um Dart SDK compatível com `^3.11.1`
- Um servidor OpenCode `1.4.3` acessível
- Toolchains de plataforma para os alvos que você planeja executar: iOS, Android, macOS ou Windows

## Começando

```bash
flutter pub get
flutter run
```

Depois adicione seu servidor OpenCode pela tela inicial, confirme que o probe de conexão passa e abra um workspace.

Para executar em um dispositivo específico:

```bash
flutter devices
flutter run -d <device-id>
```

## Desenvolvimento

Use as mesmas verificações do CI do projeto:

```bash
flutter analyze
flutter test
```

## Status do projeto

BOC está sendo preparado para release. O foco agora é estabilidade, UX multiplataforma previsível e compatibilidade com a versão suportada do OpenCode.
