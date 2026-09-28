# This fork

A personal fork of [abue-ammar/tinycast](https://github.com/abue-ammar/tinycast) that follows upstream
but lives on its own. Everything runs through [mise](https://mise.jdx.dev) tasks (`mise tasks`):

| Task | Does |
| --- | --- |
| `mise run build` / `build:release` | Debug or Release build, ad-hoc signed |
| `mise run run` | build and relaunch `Tinycast Dev.app` |
| `mise run check` | tests, lint and build |
| `mise run upstream:status` | what upstream has that `main` lacks, and the reverse |
| `mise run upstream:sync` | merge `upstream/main` into `main`, regenerate the project, build |
| `mise run branch:merge <branch>` | merge a local feature branch into `main` |

Builds are **ad-hoc signed** by passing `CODE_SIGN_IDENTITY=-` to `xcodebuild`, never by editing
`project.yml`, so the project stays byte-identical to upstream and syncs do not conflict on it. The
cost: an ad-hoc signature changes every build, so macOS asks for Accessibility again after a rebuild.

Syncing merges rather than rebases, so `main` never needs a force push. Needs `xcodegen` and
`swiftlint` (`brew install xcodegen swiftlint`).
