#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
flutter test test_tools/generate_app_icon_test.dart
