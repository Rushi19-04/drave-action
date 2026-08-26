# DRAVE Detection Validator — GitHub Action

> **Validate, score, and sync detection rules to the DRAVE SaaS platform — directly from your CI/CD pipeline.**

[![GitHub Action](https://img.shields.io/badge/GitHub%20Action-DRAVE-blue?style=for-the-badge&logo=github)](https://github.com/Rushi19-04/drave-action)

## What It Does

This Action runs the **full DRAVE Evidence Engine** against your Sigma/detection rule files:

| Stage | What It Checks |
|---|---|
| **Syntax** | Is the rule valid YAML/Sigma? |
| **Schema** | Does the rule reference fields that exist in your SIEM schema? |
| **Unit Tests** | Do your positive/negative test cases pass? |
| **Attack Replay** | Does the rule fire on known ATT&CK technique telemetry? |
| **Robustness** | Does the rule catch evasion variations (encoding, casing, etc.)? |
| **Volume** | Will the rule generate an acceptable alert volume in production? |

Results are synced to your **DRAVE Dashboard** where you can track health scores, deployment readiness, and gate status across your entire detection library.

## Quick Start

### 1. Generate an API Key

Go to your DRAVE Dashboard → **API Keys & Integrations** → **Generate New Key**.  
Copy the key and add it as a GitHub Secret named `DRAVE_API_KEY` in your repository.

### 2. Add the Action to Your Workflow

Create `.github/workflows/drave.yml` in your detection repository:

```yaml
name: DRAVE Validation

on:
  push:
    branches: [main]
    paths:
      - 'detections/rules/**.yml'
  pull_request:
    paths:
      - 'detections/rules/**.yml'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run DRAVE Validation
        uses: Rushi19-04/drave-action@v1
        with:
          rule-paths: detections/rules
          api-key: ${{ secrets.DRAVE_API_KEY }}
```

That's it. No Python installation, no dependency management, no source code to copy.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `rule-paths` | No | `detections/rules` | Path to the directory containing your detection rule YAML files. |
| `api-key` | **Yes** | — | Your DRAVE CI API Key. Pass as `${{ secrets.DRAVE_API_KEY }}`. |
| `api-url` | No | `https://drave-bfsi.onrender.com` | Override for self-hosted DRAVE instances. |

## Outputs

| Output | Description |
|---|---|
| `total` | Total number of rules processed. |
| `passed` | Rules that passed all hard gates. |
| `failed` | Rules that failed hard gates. |
| `synced` | Rules successfully synced to the DRAVE API. |

## How It Works

```
Customer Repo                           DRAVE Infrastructure
┌─────────────────┐                     ┌──────────────────────┐
│ .github/        │                     │ ghcr.io/rushi19-04/  │
│   workflows/    │  uses: drave-action │   drave-engine:v1    │
│     drave.yml ──┼────────────────────►│ (Docker container)   │
│                 │                     │                      │
│ detections/     │  mounted as volume  │ ┌──────────────────┐ │
│   rules/*.yml ──┼────────────────────►│ │ drave ci-check   │ │
│   tests/*.yml   │                     │ │ cli/sync.py      │ │
│   scenarios/    │                     │ └───────┬──────────┘ │
└─────────────────┘                     │         │            │
                                        └─────────┼────────────┘
                                                  │ HTTPS + API Key
                                        ┌─────────▼────────────┐
                                        │ DRAVE SaaS API       │
                                        │ (Render + Neon)      │
                                        │ Evidence persisted   │
                                        │ to dashboard         │
                                        └──────────────────────┘
```

**Zero proprietary source exposure:** Your repository never contains DRAVE's engine code. The validation runs inside a pre-built Docker container pulled from the GitHub Container Registry.

## Versioning

Pin to a major version for stability:
```yaml
uses: Rushi19-04/drave-action@v1   # Recommended: tracks latest v1.x.x
uses: Rushi19-04/drave-action@v1.0.0  # Exact version pin
```

## License

MIT
