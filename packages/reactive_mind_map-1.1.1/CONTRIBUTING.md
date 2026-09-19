# Contributing to Reactive Mind Map / Reactive Mind Map 기여하기

Thank you for your interest in contributing to Reactive Mind Map! / Reactive Mind Map에 기여해주셔서 감사합니다!

## Code of Conduct / 행동 강령

By participating in this project, you agree to abide by our code of conduct. Please be respectful and constructive in all interactions.

이 프로젝트에 참여함으로써 행동 강령을 준수하는 데 동의합니다. 모든 상호작용에서 존중하고 건설적으로 행동해주세요.

## How to Contribute / 기여 방법

### Reporting Bugs / 버그 신고

Before reporting a bug, please:
버그를 신고하기 전에 다음을 확인해주세요:

1. Check the [existing issues](https://github.com/devpark435/reactive_mind_map/issues) / [기존 이슈들](https://github.com/devpark435/reactive_mind_map/issues)을 확인하세요
2. Make sure you're using the latest version / 최신 버전을 사용하고 있는지 확인하세요
3. Try to reproduce the issue with a minimal example / 최소한의 예제로 문제를 재현해보세요

Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml) when creating a new issue.
새 이슈를 생성할 때 [버그 리포트 템플릿](.github/ISSUE_TEMPLATE/bug_report.yml)을 사용하세요.

### Suggesting Features / 기능 제안

We welcome feature suggestions! Please:
기능 제안을 환영합니다! 다음을 확인해주세요:

1. Check if the feature already exists or is planned / 기능이 이미 존재하거나 계획되어 있는지 확인하세요
2. Consider if it fits the scope of the library / 라이브러리의 범위에 맞는지 고려하세요
3. Provide a clear use case / 명확한 사용 사례를 제공하세요

Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml) when suggesting new features.
새로운 기능을 제안할 때 [기능 요청 템플릿](.github/ISSUE_TEMPLATE/feature_request.yml)을 사용하세요.

### Asking Questions / 질문하기

For questions about usage, please:
사용법에 대한 질문은 다음을 확인해주세요:

1. Check the [README](README.md) documentation / [README](README.md) 문서를 확인하세요
2. Look at the [example code](lib/main.dart) / [예제 코드](lib/main.dart)를 살펴보세요
3. Search existing issues / 기존 이슈들을 검색해보세요

Use the [Question template](.github/ISSUE_TEMPLATE/question.yml) for questions.
질문은 [질문 템플릿](.github/ISSUE_TEMPLATE/question.yml)을 사용하세요.

## Development Setup / 개발 환경 설정

### Prerequisites / 사전 요구사항

- Flutter 3.0 or higher / Flutter 3.0 이상
- Dart 3.7.2 or higher / Dart 3.7.2 이상

### Getting Started / 시작하기

1. Fork the repository / 저장소를 포크하세요
2. Clone your fork / 포크한 저장소를 클론하세요:
   ```bash
   git clone https://github.com/YOUR_USERNAME/reactive_mind_map.git
   cd reactive_mind_map
   ```

3. Install dependencies / 의존성을 설치하세요:
   ```bash
   flutter pub get
   ```

4. Run the example / 예제를 실행하세요:
   ```bash
   flutter run
   ```

5. Run tests / 테스트를 실행하세요:
   ```bash
   flutter test
   ```

### Making Changes / 변경사항 만들기

1. Create a new branch / 새 브랜치를 생성하세요:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes / 변경사항을 만드세요
3. Add tests for your changes / 변경사항에 대한 테스트를 추가하세요
4. Run tests to ensure everything works / 모든 것이 작동하는지 테스트를 실행하세요:
   ```bash
   flutter test
   flutter analyze
   ```

5. Commit your changes / 변경사항을 커밋하세요:
   ```bash
   git commit -m "feat: add new feature"
   ```

### Commit Message Format / 커밋 메시지 형식

We use conventional commits. Format: `type(scope): description`
관례적 커밋을 사용합니다. 형식: `type(scope): description`

Types / 타입:
- `feat`: New feature / 새로운 기능
- `fix`: Bug fix / 버그 수정
- `docs`: Documentation / 문서화
- `style`: Code style / 코드 스타일
- `refactor`: Code refactoring / 코드 리팩토링
- `test`: Tests / 테스트
- `chore`: Maintenance / 유지보수

Examples / 예시:
- `feat: add radial layout support`
- `fix: resolve animation flickering issue`
- `docs: update installation instructions`

### Pull Request Process / Pull Request 과정

1. Create a pull request using the [template](.github/pull_request_template.md) / [템플릿](.github/pull_request_template.md)을 사용하여 pull request를 생성하세요
2. Wait for review / 리뷰를 기다리세요

## Coding Standards / 코딩 표준

### Dart Style / Dart 스타일

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style) / [Dart 스타일 가이드](https://dart.dev/guides/language/effective-dart/style)를 따르세요
- Use `dart format` to format code / `dart format`을 사용하여 코드를 포맷하세요
- Fix all analyzer warnings / 모든 분석기 경고를 수정하세요

### Documentation / 문서화

- Document all public APIs / 모든 공개 API를 문서화하세요
- Format: `/// Korean description / English description`
- Provide code examples for complex features / 복잡한 기능에는 코드 예제를 제공하세요

### Testing / 테스트

- Write tests for new features / 새로운 기능에 대한 테스트를 작성하세요
- Maintain high test coverage / 높은 테스트 커버리지를 유지하세요
- Test on multiple platforms when possible / 가능한 경우 여러 플랫폼에서 테스트하세요

## Release Process / 릴리스 과정

1. Update version in `pubspec.yaml` / `pubspec.yaml`에서 버전을 업데이트하세요
2. Update `CHANGELOG.md` / `CHANGELOG.md`를 업데이트하세요
3. Create a release tag / 릴리스 태그를 생성하세요
4. Publish to pub.dev / pub.dev에 게시하세요

## Getting Help / 도움 받기

If you need help with your contribution:
기여에 도움이 필요한 경우:

- Create a [Question issue](https://github.com/devpark435/reactive_mind_map/issues/new?template=question.yml) / [질문 이슈](https://github.com/devpark435/reactive_mind_map/issues/new?template=question.yml)를 생성하세요
- Check existing discussions / 기존 토론을 확인하세요
- Look at similar contributions / 유사한 기여를 살펴보세요

## Recognition / 인정

All contributors will be:
모든 기여자는 다음과 같이 인정받습니다:

- Listed in the CHANGELOG / CHANGELOG에 나열됩니다
- Mentioned in release notes / 릴리스 노트에 언급됩니다
- Added to contributors list / 기여자 목록에 추가됩니다

Thank you for contributing! / 기여해주셔서 감사합니다! 