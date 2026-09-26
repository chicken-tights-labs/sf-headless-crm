#!/bin/bash
# Set up GitHub secrets for Salesforce CI/CD
# Run this after you have your DE org credentials
# Usage: ./scripts/setup-secrets.sh USERNAME PASSWORD SECURITY_TOKEN

set -e

if [ "$#" -ne 3 ]; then
    echo "Usage: ./scripts/setup-secrets.sh <username> <password> <security_token>"
    echo ""
    echo "Example:"
    echo "  ./scripts/setup-secrets.sh maria.robbins@boxinggym.developper.my.salesforce.com 'MyP@ssw0rd!' abcdefg1234567"
    exit 1
fi

SF_USERNAME="$1"
SF_PASSWORD="$2"
SF_SECURITY_TOKEN="$3"
REPO="chicken-tights-labs/sf-headless-crm"

echo "🔐 Setting up GitHub secrets for $REPO..."
echo ""

gh secret set SF_USERNAME --body "$SF_USERNAME" -R "$REPO"
echo "  ✅ SF_USERNAME"

gh secret set SF_PASSWORD --body "$SF_PASSWORD" -R "$REPO"
echo "  ✅ SF_PASSWORD"

gh secret set SF_SECURITY_TOKEN --body "$SF_SECURITY_TOKEN" -R "$REPO"
echo "  ✅ SF_SECURITY_TOKEN"

gh secret set SF_INSTANCE_URL --body "https://test.salesforce.com" -R "$REPO"
echo "  ✅ SF_INSTANCE_URL"

gh secret set SF_DEFAULT_USERNAME --body "$SF_USERNAME" -R "$REPO"
echo "  ✅ SF_DEFAULT_USERNAME"

echo ""
echo "✅ All GitHub secrets configured!"
echo ""
echo "Next steps:"
echo "  1. Re-enable push trigger in .github/workflows/deploy.yml (uncomment the push lines)"
echo "  2. git commit --allow-empty -m 'chore: enable CI/CD deploy trigger' && git push"
echo "  3. gh run watch  # to see the deployment run"
