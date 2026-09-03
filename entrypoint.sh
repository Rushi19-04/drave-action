#!/bin/bash
# ──────────────────────────────────────────────────────────────
# DRAVE Action Entrypoint
#
# Runs `drave ci-check` against the customer's rule files,
# then syncs results to the DRAVE SaaS API via cli/sync.py.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Inputs (set by GitHub Actions from action.yml) ──
RULE_PATHS="${INPUT_RULE_PATHS:-detections/rules}"
API_KEY="${INPUT_API_KEY:-}"
API_URL="${INPUT_API_URL:-https://drave-bfsi.onrender.com}"

if [ -z "$API_KEY" ]; then
  echo "::error::DRAVE_API_KEY is required. Generate one from the DRAVE Dashboard → API Keys & Integrations."
  exit 1
fi

# Export for cli/sync.py
export DRAVE_API_KEY="$API_KEY"
export API_BASE_URL="$API_URL"

# ── Discover rule files ──
if [ "${INPUT_BOOTSTRAP:-false}" = "true" ]; then
  echo "Running in Bootstrap Mode: Discovering all rules..."
  # Use python scanner to get all rule paths (using the engine environment)
  RULE_FILES=$(cd /engine && uv run python -c "from core.discovery.scanner import RepositoryScanner; inv = RepositoryScanner('${GITHUB_WORKSPACE:-$PWD}').scan(); print('\n'.join(inv.rule_paths.keys()))")
else
  echo "Running in Incremental Mode: Resolving affected rules via Git Diff..."
  RULE_FILES=$(cd /engine && uv run python -m cli.incremental --workspace "${GITHUB_WORKSPACE:-$PWD}")
  
  if [ -z "$RULE_FILES" ]; then
    echo "0 affected rules found based on git diff."
    echo "::notice::No detection rules require validation for this commit."
    exit 0
  fi
fi

if [ -z "$RULE_FILES" ]; then
  echo "::warning::No valid rules discovered."
  exit 0
fi

TOTAL=0
PASSED=0
FAILED=0
SYNCED=0
SYNC_FAILED=0

echo "═══════════════════════════════════════════════════"
echo "  DRAVE Detection Validation Engine"
echo "═══════════════════════════════════════════════════"
echo ""

WORKSPACE_DIR="${GITHUB_WORKSPACE:-$PWD}"

for file in $RULE_FILES; do
  TOTAL=$((TOTAL + 1))
  
  if [[ "$file" = /* ]]; then
    ABS_PATH="$file"
  else
    ABS_PATH="${WORKSPACE_DIR}/${file#./}"
    ABS_PATH="${ABS_PATH//\/\///}"
  fi

  echo "──────────────────────────────────────────────"
  echo "  Validating: $ABS_PATH"
  echo "──────────────────────────────────────────────"

  # Step 1: Run real evidence computation via ci-check
  if (cd /engine && uv run drave ci-check "$ABS_PATH" --workspace "$WORKSPACE_DIR"); then
    PASSED=$((PASSED + 1))
    echo "✅ Validation passed for $file"
  else
    FAILED=$((FAILED + 1))
    echo "::warning file=$file::Validation failed for $file (hard gates not passed)"
    # Don't exit — continue processing other rules, but sync anyway
    # so the dashboard shows the real failing evidence
  fi

  # Step 2: Sync to DRAVE SaaS API (real evidence, not hardcoded)
  echo "  → Syncing evidence to DRAVE API..."
  export DRAVE_WORKSPACE="$WORKSPACE_DIR"
  if (cd /engine && uv run python -m cli.sync "$ABS_PATH" > "$WORKSPACE_DIR/api_sync_$TOTAL.log" 2>&1); then
    SYNCED=$((SYNCED + 1))
    echo "✅ Synced $file to DRAVE API"
  else
    SYNC_FAILED=$((SYNC_FAILED + 1))
    echo "::warning file=$file::Failed to sync $file to DRAVE API"
  fi

  echo ""
done

echo "═══════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════"
echo "  Total rules:       $TOTAL"
echo "  Validation passed: $PASSED"
echo "  Validation failed: $FAILED"
echo "  Synced to API:     $SYNCED"
echo "  Sync failures:     $SYNC_FAILED"
echo "═══════════════════════════════════════════════════"

# Set outputs for downstream workflow steps
echo "total=$TOTAL" >> "$GITHUB_OUTPUT"
echo "passed=$PASSED" >> "$GITHUB_OUTPUT"
echo "failed=$FAILED" >> "$GITHUB_OUTPUT"
echo "synced=$SYNCED" >> "$GITHUB_OUTPUT"

# Exit non-zero if any validation failed
if [ "$FAILED" -gt 0 ]; then
  echo "::error::$FAILED rule(s) failed hard gate validation."
  exit 1
fi
