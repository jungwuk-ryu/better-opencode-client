# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Icône de l'application BOC" width="112">
</p>

OpenCode à distance, sans rester collé à votre bureau.

BOC est un client Flutter multiplateforme pour utiliser OpenCode à distance depuis iOS, Android, macOS et Windows. Il est conçu autour de la compatibilité avec OpenCode `1.4.3` et se concentre sur le travail réellement utile lorsque vous êtes loin de votre station principale : se connecter à un serveur, reprendre un workspace, suivre les sessions, répondre aux demandes, inspecter le contexte et lancer une commande shell si nécessaire.

Vous avez un grand écran ?

![Workspace multipanneau de BOC](assets/readme/multi-pane.png)

BOC peut s'étendre en centre de commande multipanneau pour le suivi des sessions, la Review, les fichiers, le contexte, la sortie shell et l'activité parallèle du workspace.

## Pourquoi BOC

- **Workflow remote-first** : enregistrez des serveurs OpenCode, vérifiez l'état de connexion et revenez rapidement au bon workspace.
- **Contrôles natifs mobiles** : navigation tactile, layouts compacts, saisie vocale, pièces jointes, notifications et actions à une main.
- **Workspace de niveau bureau** : les grands écrans profitent de split panes, panneaux latéraux, listes de sessions, surfaces de Review et détails de contexte sans devenir une vue mobile compressée.
- **Retour opérationnel en direct** : sortie shell, questions en attente, permissions, todos, usage du contexte et activité de session restent visibles pendant l'exécution.
- **Gestion prévisible des serveurs** : les entrées serveur sont faciles à parcourir, actualiser, modifier, supprimer et reconnecter.

## Fonctionnalités principales

- Gérer plusieurs serveurs OpenCode distants depuis un écran d'accueil simple.
- Tester la santé et la compatibilité du serveur avant d'entrer dans un workspace.
- Parcourir projets et sessions, y compris les prompts récents et les sessions enfants actives.
- Discuter avec des sessions OpenCode via slash commands, pièces jointes, sélection de modèle et contrôles de reasoning.
- Répondre aux questions et demandes de permission sans perdre votre place dans la conversation.
- Inspecter l'usage du contexte, les fichiers, les review diffs, les éléments inbox, les todos et l'activité shell dans des panneaux dédiés.
- Ouvrir des onglets terminal quand l'interface guidée ne suffit pas.
- Utiliser des layouts adaptatifs sur téléphones, tablettes, laptops et écrans de bureau.

## Compatibilité

BOC cible OpenCode `1.4.3`. La validation actuelle de préparation de release couvre le probe de connexion, le chargement workspace/session, le chat, les flux shell et terminal, les questions en attente, les demandes de permission, les panneaux review/files/context et les layouts multipanneaux adaptatifs.

Plateformes clientes prises en charge :

- iOS
- Android
- macOS
- Windows

Le serveur OpenCode s'exécute toujours à distance ; BOC est la surface cliente pour s'y connecter, pas un remplacement du serveur lui-même.

## Prérequis

- Flutter avec un Dart SDK compatible avec `^3.11.1`
- Un serveur OpenCode `1.4.3` accessible
- Les toolchains de plateforme pour les cibles prévues : iOS, Android, macOS ou Windows

## Démarrage

```bash
flutter pub get
flutter run
```

Ajoutez ensuite votre serveur OpenCode depuis l'écran d'accueil, confirmez que le probe de connexion réussit, puis ouvrez un workspace.

Pour exécuter sur un appareil précis :

```bash
flutter devices
flutter run -d <device-id>
```

## Développement

Utilisez les mêmes vérifications que la CI du projet :

```bash
flutter analyze
flutter test
```

## État du projet

BOC est en préparation pour la release. L'accent est mis sur la stabilité, une UX multiplateforme prévisible et la compatibilité avec la version OpenCode prise en charge.
