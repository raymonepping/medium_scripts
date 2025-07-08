# Vault Radar Scenarios

[![](https://img.shields.io/badge/High-red)](#high) [![](https://img.shields.io/badge/Medium-yellow)](#medium) [![](https://img.shields.io/badge/Low-lightgrey)](#low) [![](https://img.shields.io/badge/Secret-purple)](#secret) [![](https://img.shields.io/badge/Pii-orange)](#pii) [![](https://img.shields.io/badge/Non%20inclusive-green)](#non-inclusive)

---
| Label | Severity | Category | Languages |
|---|---|---|---|
| [Blacklist (non_inclusive / inclusivity)](#blacklist-noninclusive-inclusivity) | 🟢 low | 🌈 non_inclusive | bash, python, docker, terraform, node |
| [Master branch (non_inclusive / inclusivity)](#master-branch-noninclusive-inclusivity) | 🟢 low | 🌈 non_inclusive | bash, python, docker, terraform, node |
| [SSN (pii / PII)](#ssn-pii-pii) | 🚨 high | 📧 pii | python, terraform, bash |
| [Email (pii / PII)](#email-pii-pii) | 🟡 medium | 📧 pii | bash, python, node |
| [AWS Access Key (secret / AWS)](#aws-access-key-secret-aws) | 🚨 high | 🗝️ secret | bash, python, docker, terraform, node |
| [GitHub Token (secret / github)](#github-token-secret-github) | 🚨 high | 🗝️ secret | bash, python, node, docker |

---

<details>
<summary>🚨 <b>High Severity</b></summary>

### SSN (pii / PII) 🚨

- **Value:** `123-45-6789`
- **Languages:** python, terraform, bash
- **Severity:** high ![](https://img.shields.io/badge/High-high-red)
- **Category:** pii 📧 ![](https://img.shields.io/badge/Pii-pii-blue)
- **Author:** test
- **Source:** fake db

> US social security number

[⬆️ Back to top](#vault-radar-scenarios)

---
### AWS Access Key (secret / AWS) 🚨

- **Value:** `AWS_ACCESS_KEY_ID=AKIA1234567890FAKE`
- **Languages:** bash, python, docker, terraform, node
- **Severity:** high ![](https://img.shields.io/badge/High-high-red)
- **Category:** secret 🗝️ ![](https://img.shields.io/badge/Secret-secret-blue)
- **Author:** raymon.epping
- **Source:** test suite

> Classic AWS secret pattern

[⬆️ Back to top](#vault-radar-scenarios)

---
### GitHub Token (secret / github) 🚨

- **Value:** `GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz`
- **Languages:** bash, python, node, docker
- **Severity:** high ![](https://img.shields.io/badge/High-high-red)
- **Category:** secret 🗝️ ![](https://img.shields.io/badge/Secret-secret-blue)
- **Author:** test
- **Source:** examples

> GitHub personal access token format

[⬆️ Back to top](#vault-radar-scenarios)

---
</details>

<details>
<summary>🟡 <b>Medium Severity</b></summary>

### Email (pii / PII) 🟡

- **Value:** `john.doe@example.com`
- **Languages:** bash, python, node
- **Severity:** medium ![](https://img.shields.io/badge/Medium-medium-red)
- **Category:** pii 📧 ![](https://img.shields.io/badge/Pii-pii-blue)
- **Author:** test
- **Source:** public db

> Sample email leak

[⬆️ Back to top](#vault-radar-scenarios)

---
</details>

<details>
<summary>🟢 <b>Low Severity</b></summary>

### Blacklist (non_inclusive / inclusivity) 🟢

- **Value:** `blacklist`
- **Languages:** bash, python, docker, terraform, node
- **Severity:** low ![](https://img.shields.io/badge/Low-low-red)
- **Category:** non_inclusive 🌈 ![](https://img.shields.io/badge/Non_inclusive-non_inclusive-blue)
- **Author:** test
- **Source:** old code

> Non-inclusive legacy term

[⬆️ Back to top](#vault-radar-scenarios)

---
### Master branch (non_inclusive / inclusivity) 🟢

- **Value:** `master branch`
- **Languages:** bash, python, docker, terraform, node
- **Severity:** low ![](https://img.shields.io/badge/Low-low-red)
- **Category:** non_inclusive 🌈 ![](https://img.shields.io/badge/Non_inclusive-non_inclusive-blue)
- **Author:** test
- **Source:** legacy vcs

> Legacy VCS term

[⬆️ Back to top](#vault-radar-scenarios)

---
</details>

## Table of Contents
- [Blacklist (non_inclusive / inclusivity)](#blacklist-noninclusive-inclusivity)
- [Master branch (non_inclusive / inclusivity)](#master-branch-noninclusive-inclusivity)
- [SSN (pii / PII)](#ssn-pii-pii)
- [Email (pii / PII)](#email-pii-pii)
- [AWS Access Key (secret / AWS)](#aws-access-key-secret-aws)
- [GitHub Token (secret / github)](#github-token-secret-github)

