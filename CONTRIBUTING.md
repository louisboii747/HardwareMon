# Contributing to HardwareMon

Thank you for your interest in contributing to HardwareMon!

HardwareMon is an open-source cross-platform system monitoring application built with a Flutter frontend and a FastAPI backend. The project is actively developed and contributions of all sizes are welcome, whether that's fixing bugs, improving documentation, refining the UI, or adding new features.

## Before You Start

For major features, architectural changes, or large refactors, please open an issue first so the proposed changes can be discussed before work begins.

Smaller fixes and improvements can be submitted directly as pull requests.

## Development Setup

### Prerequisites

Install the following software before contributing:

- Git
- Flutter SDK
- Python 3.11 or newer
- Visual Studio Build Tools (Windows development)
- A code editor such as VS Code

Verify your environment:

```bash
flutter doctor
python --version
git --version
```

### Clone the Repository

```bash
git clone https://github.com/louisdevdev/hardwaremon.git
cd hardwaremon
```

### Python Environment

Create and activate a virtual environment:

#### Windows

```bash
python -m venv .venv
.venv\Scripts\activate
```

#### Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install Python dependencies:

```bash
pip install -r requirements.txt
```

### Running the Backend

HardwareMon uses FastAPI and Uvicorn for its backend services.

Start the backend with:

```bash
uvicorn main:app --reload
```

### Running the Frontend

Install Flutter dependencies:

```bash
flutter pub get
```

Launch the application:

```bash
flutter run
```

### Windows Telemetry

HardwareMon uses LibreHardwareMonitor internally to collect hardware telemetry on Windows.

No separate installation is required if the project dependencies are configured correctly.

Some telemetry features may require administrator privileges depending on the sensors available on the system.

### Verify Your Setup

A successful setup should allow you to:

- Launch the Flutter application
- Connect to the backend successfully
- View live telemetry data
- Navigate between application pages without errors

If telemetry is unavailable, check backend logs before opening an issue.

## Coding Guidelines

### Flutter

- Follow the existing project structure.
- Use meaningful widget and class names.
- Keep widgets reusable where practical.
- Maintain consistency with the existing UI.

### Python

- Follow PEP 8 where practical.
- Use clear and descriptive names.
- Keep API responses consistent.
- Avoid unnecessary complexity.

### General

- Write readable and maintainable code.
- Avoid introducing unnecessary dependencies.
- Keep pull requests focused on a single purpose.
- Test your changes before submitting them.

## Commit Messages

Use clear and descriptive commit messages.

Examples:

```text
feat: add GPU VRAM telemetry card
fix: resolve settings page crash
docs: update installation guide
refactor: simplify telemetry service
```

Avoid vague commit messages such as:

```text
update
fixes
stuff
changes
```

## Pull Requests

When opening a pull request:

- Clearly explain what changed.
- Explain why the change was made.
- Include screenshots for UI changes when possible.
- Keep the scope focused and manageable.

## Reporting Bugs

Please include:

- Operating system
- HardwareMon version
- Steps to reproduce
- Expected behaviour
- Actual behaviour
- Screenshots or logs if available

## Feature Requests

Feature suggestions are always welcome.

When proposing a feature, include:

- The problem it solves
- Why it would be useful
- Any implementation ideas you have

## Project Goals

HardwareMon aims to be:

- Cross-platform
- Lightweight
- Modern and responsive
- Easy to install
- Open source
- Developer friendly

Contributions should generally align with these goals.

## Code of Conduct

Please be respectful and constructive when interacting with other contributors.

Harassment, discrimination, trolling, or hostile behaviour will not be tolerated.

## Thank You

Every contribution helps improve HardwareMon.

Whether you're fixing a typo, improving documentation, reporting a bug, or developing a major feature, your contribution is appreciated.
