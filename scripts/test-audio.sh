#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I Sources/AudioRender/include Sources/AudioRender/AudioRender.c \
  Tests/AudioRenderTests/render_tests.c -o .build/tests/render-tests
.build/tests/render-tests
