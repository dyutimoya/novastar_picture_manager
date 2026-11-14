# Contributing to Novastar Picture Manager

Thank you for your interest in contributing to **Novastar Picture Manager**! As an open-source project, we value contributions from developers of all skill levels.

To maintain high code quality, security, and stability across 6 supported platforms, we have established guidelines and strict branch protection rules. Please read this document before creating issues or pull requests.

---

## 🛡️ Master Branch Protection Policy

The `master` (or `main`) branch is **strictly protected** and represents production-ready code.

### Rules Enforced on `master`:
1. **No Direct Pushes**: Direct commits or pushes to the `master` branch are blocked for everyone (including repository admins).
2. **Pull Requests Required**: All changes must be submitted via a Pull Request (PR) from a separate topic branch or a fork.
3. **Mandatory CI Checks**: A PR cannot be merged until all automated GitHub Actions CI checks pass:
   - `flutter analyze --no-fatal-infos` (0 errors, 0 warnings)
   - `flutter test` (100% test suites passing)
   - Platform build sanity checks (Linux, Web, Android)
4. **Code Review Requirement**: At least one approving review from a project maintainer is required before merge.
5. **Up-to-Date Branches**: Branches must be rebased or updated against latest `master` before merging.
6. **Clean Git History**: PRs should use **Squash and Merge** or **Rebase and Merge** to maintain a clean, linear git history.

---

## 🌿 Branching Strategy

When working on a change, branch off the latest `master` using the following naming conventions:

| Branch Prefix | Purpose | Example |
| :--- | :--- | :--- |
| `feature/` | New capabilities or enhancements | `feature/smart-face-detection` |
| `fix/` | Bug fixes or issue resolutions | `fix/windows-ico-transparency` |
| `perf/` | Performance optimizations | `perf/isolate-memory-caching` |
| `refactor/` | Code structure improvements without behavior change | `refactor/crop-math-simplification` |
| `docs/` | Documentation improvements | `docs/update-linux-install-guide` |
| `test/` | Adding or updating unit/widget tests | `test/export-dialog-tests` |

---

## 📝 Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short description in imperative mood>

[optional body explaining motivation and details]

[optional footer: Closes #123]
```

### Allowed Types:
- `feat`: A new user-facing feature.
- `fix`: A bug fix.
- `docs`: Documentation-only changes.
- `style`: Changes that do not affect the meaning of the code (whitespace, formatting).
- `refactor`: A code change that neither fixes a bug nor adds a feature.
- `perf`: A code change that improves performance.
- `test`: Adding missing tests or correcting existing tests.
- `chore`: Maintenance tasks, dependencies, build scripts.

### Examples:
- `feat(crop): add freeform aspect ratio lock preset`
- `fix(export): prevent accidental file overwrite on collision`
- `docs(readme): add Linux packaging commands`

---

## 🔄 Pull Request Workflow

Follow these steps to submit your contribution:

### 1. Fork & Clone
```bash
git clone https://github.com/<your-username>/novastar-picture-manager.git
cd novastar-picture-manager
git remote add upstream https://github.com/novastar/novastar-picture-manager.git
```

### 2. Create a Feature Branch
```bash
git fetch upstream
git checkout -b feature/your-feature-name upstream/master
```

### 3. Make Your Changes
- Follow Flutter and Dart best practices.
- Maintain existing architecture (Clean Architecture, Riverpod, Isolates).
- Keep UI responsive during heavy processing.

### 4. Format & Verify Locally
Before submitting, run all verification steps:

```bash
# 1. Format all Dart files
dart format --line-length=120 .

# 2. Run static analysis (must report zero warnings/errors)
flutter analyze --no-fatal-infos

# 3. Run all unit and widget tests
flutter test
```

### 5. Submit the Pull Request
- Push your branch to your fork.
- Open a PR targeting the `master` branch.
- Fill out the provided **Pull Request Template** completely.
- Link relevant issues (e.g., `Closes #42`).
- Include screenshots or GIFs if your PR modifies UI elements.

---

## ✅ Pull Request Checklist

Before submitting your PR, verify that:
- [ ] My code follows the code style and architectural boundaries of this project.
- [ ] I have executed `dart format --line-length=120 .` on my changes.
- [ ] `flutter analyze --no-fatal-infos` passes with 0 errors and 0 warnings.
- [ ] All new and existing unit tests pass via `flutter test`.
- [ ] I have added tests for any new logic or bug fixes.
- [ ] My commit messages follow Conventional Commits.
- [ ] If changing the UI, I have attached screenshots or screen recordings.
- [ ] I have updated any relevant documentation (`README.md`, `ARCHITECTURE.md`).

---

## 🧪 Testing Guidelines

Every new feature or bug fix must include automated test coverage:

- **Unit Tests (`test/crop_and_batch_test.dart`)**: Test domain models, crop math, normalized coordinates, resize ratios, naming engines, and file utilities.
- **Widget Tests (`test/widget_test.dart`)**: Test screen rendering, user interactions, dialog confirmations, and widget lifecycles.
- **Isolate Safety**: Ensure background isolate tasks gracefully handle cancellation and report errors back to the main thread.

---

## 💬 Community & Questions

If you encounter questions or want to discuss a large proposal before writing code:
- Open a [Discussion](https://github.com/novastar/novastar-picture-manager/discussions) on GitHub.
- Open a [Feature Request Issue](https://github.com/novastar/novastar-picture-manager/issues/new?template=feature_request.md).

Thank you for helping make **Novastar Picture Manager** the best image editor for everyone!
