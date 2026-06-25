#!/usr/bin/env bash
# Bloqueia commit se detectar padrões de segredo em arquivos staged.
# Uso: scripts/check-secrets.sh
# Hook: ln -sf ../../scripts/check-secrets.sh .git/hooks/pre-commit
set -e

PATTERNS=(
  'AIzaSy[A-Za-z0-9_-]{30,}'
  '"access_token"[[:space:]]*:[[:space:]]*"[A-Za-z0-9_-]{20,}"'
  '"consumer_(key|secret)"[[:space:]]*:[[:space:]]*"[A-Za-z0-9_-]{20,}"'
  'papelcia2024'
)

FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(json|md|yml|yaml|env)$' || true)

if [ -z "$FILES" ]; then
  exit 0
fi

FOUND=0
for f in $FILES; do
  for p in "${PATTERNS[@]}"; do
    if grep -EnH "$p" "$f" > /dev/null 2>&1; then
      echo "❌ Possível segredo encontrado em $f (padrão: $p)"
      grep -EnH "$p" "$f"
      FOUND=1
    fi
  done
done

if [ "$FOUND" -eq 1 ]; then
  echo ""
  echo "Commit bloqueado. Remova os segredos ou use placeholder antes de commitar."
  exit 1
fi

exit 0