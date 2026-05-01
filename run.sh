#!/usr/bin/env bash
# Lance l'app Flutter en injectant les variables d'environnement de `.env`
# comme `--dart-define`, sans jamais les écrire dans les sources.
#
# Usage : ./run.sh [device]
#   ./run.sh                 # device par défaut
#   ./run.sh chrome          # web
#   ./run.sh "iPhone 15"     # simulateur iOS
#
# Tout argument supplémentaire est passé tel quel à `flutter run`.

set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
DEFINES=()

if [[ -f "$ENV_FILE" ]]; then
  while IFS='=' read -r key value; do
    # Ignore commentaires & lignes vides
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    # Trim guillemets entourants
    value="${value%\"}"
    value="${value#\"}"
    DEFINES+=("--dart-define=$key=$value")
  done < <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
else
  echo "⚠️  $ENV_FILE introuvable — copiez .env.example puis éditez-le."
fi

DEVICE_ARGS=()
if [[ $# -gt 0 ]]; then
  DEVICE_ARGS=(-d "$1")
  shift
fi

exec flutter run "${DEVICE_ARGS[@]}" "${DEFINES[@]}" "$@"
