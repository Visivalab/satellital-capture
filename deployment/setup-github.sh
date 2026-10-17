#!/usr/bin/env bash
# Configures the repository secrets, variables and environment used by
# publish.yml/deploy.yml. Run locally with an authenticated gh CLI.
# Secret values are typed or read from files; they are never echoed.
set -euo pipefail

REPO=Visivalab/satellital-capture
KEY_FILE="${1:-$HOME/.ssh/visivalab-ci-deploy}"

[[ -f $KEY_FILE ]] || { echo "CI private key not found: $KEY_FILE (pass its path as the first argument)"; exit 1; }

read -rp 'DEPLOY_HOST (same as Storylab, e.g. visivalabserver.tail961be9.ts.net): ' host
read -rp 'DEPLOY_PORT [22]: ' port
port="${port:-22}"

echo 'Paste the TS_OAUTH_CLIENT_ID:'
gh secret set TS_OAUTH_CLIENT_ID -R "$REPO"
echo 'Paste the TS_OAUTH_SECRET:'
gh secret set TS_OAUTH_SECRET -R "$REPO"
gh secret set DEPLOY_SSH_PRIVATE_KEY -R "$REPO" < "$KEY_FILE"
echo 'Paste the DEPLOY_KNOWN_HOSTS line (same one as Storylab):'
gh secret set DEPLOY_KNOWN_HOSTS -R "$REPO"

gh variable set DEPLOY_HOST -R "$REPO" --body "$host"
gh variable set DEPLOY_PORT -R "$REPO" --body "$port"
gh api -X PUT "repos/$REPO/environments/production" > /dev/null

echo "GitHub configured for $REPO."
