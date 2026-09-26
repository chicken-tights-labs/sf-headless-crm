#!/bin/bash
# Salesforce Deploy Helper — Boxing Gym CRM to Partner Dev Org
# Usage: ./deploy.sh
# Run this after authenticating to your Partner Dev Org with `sf org login web`

set -e

echo "🚀 Boxing Gym CRM Deployment Helper"
echo "======================================"
echo ""

# Check if authenticated
if ! sf org list --all 2>/dev/null | grep -q "partner-dev\|login.salesforce"; then
    echo "🔐 No authenticated org found."
    echo ""
    echo "To authenticate, run one of these:"
    echo "  1. Web login (opens browser on this VM):"
    echo "     sf org login web --alias partner-dev --set-default"
    echo ""
    echo "  2. Web login without browser (prints URL you open on your laptop):"
    echo "     sf org login web --alias partner-dev --set-default --no-browser"
    echo ""
    echo "  3. Username/password (if you have credentials):"
    echo "     sf org login user --alias partner-dev --set-default \\"
    echo "       --instance-url https://test.salesforce.com \\"
    echo "       --username YOUR_USERNAME"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

echo "✓ Org authenticated"
echo ""

# Verify connection
echo "🔍 Checking org connection..."
ORGS=$(sf org list --all --json 2>/dev/null | python3 -c "
import sys, json
orgs = json.load(sys.stdin).get('result', [])
for o in orgs:
    if o.get('default') or o.get('username') != '--':
        print(f\"{o.get('username','?')} ({o.get('instanceUrl','?')})\")
" 2>/dev/null || echo "Unable to parse orgs")
echo "  Connected orgs: $ORGS"
echo ""

# Deploy metadata
echo "📦 Deploying metadata to org..."
sf project deploy start \
    --source-dir force-app \
    --test-level RunLocalTests \
    --json 2>&1 | python3 -c "
import sys, json
result = json.load(sys.stdin)
if result.get('result', {}).get('status') == 'Succeeded':
    print('✅ Deployment succeeded!')
    # Show summary
    deployed = result['result'].get('deployedSource', [])
    print(f'   {len(deployed)} components deployed')
    for item in deployed[:10]:
        print(f'   - {item.get(\"fullName\", \"?\")} ({item.get(\"componentType\", \"?\")})')
    if len(deployed) > 10:
        print(f'   ... and {len(deployed) - 10} more')
elif result.get('result', {}).get('status') == 'Failed':
    print('❌ Deployment failed!')
    for err in result['result'].get('details', {}).get('componentFailures', []):
        print(f'   {err.get(\"fullName\", \"?\")}: {err.get(\"problem\", \"?\")}')
else:
    print(json.dumps(result, indent=2)[:500])
" || echo "❌ Deploy command failed"

echo ""
echo "📋 Post-deploy verification..."
echo "  Running SOQL queries to verify objects..."
for obj in Franchise_Location__c Franchise_Owner__c Member__c Lead__c; do
    sf data query --target-org partner-dev \
        -q "SELECT COUNT() FROM ${obj}" \
        --json 2>/dev/null | python3 -c "
import sys, json
r = json.load(sys.stdin)
if 'result' in r:
    count = r['result'].get('totalSize', 0)
    print(f'  ✅ {obj}: {count} records')
else:
    print(f'  ❌ {obj}: query failed')
" 2>/dev/null || echo "  ⚠️  ${obj}: query failed"
done

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. Set up GitHub secrets: gh secret set SF_USERNAME --body 'your_username'"
echo "  2. Push to GitHub: git add . && git commit -m 'fix: deploy from VM' && git push"
echo "  3. Check CI/CD: gh run watch"
