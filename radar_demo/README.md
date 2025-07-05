# Vault Radar Demo Framework

**A flexible, CLI-driven toolkit to simulate real-world code leaks for secrets, PII, and non-inclusive language — designed for testing Vault Radar, Gitleaks, TruffleHog, and other security scanners.**

---

## 🎯 Purpose

This demo is for **testing and demonstrating secret/PII/inclusive language detection** tools (like HashiCorp Vault Radar) in a repeatable, flexible, and educational way.

- Seeds real-looking leaks across Bash, Python, Node.js, Dockerfile, and Terraform scripts.
- Uses a single input JSON for reproducible but randomized test scenarios.
- Supports filtering by language, scenario (e.g., AWS, PII), and custom header/footer templates.

---

## ⚙️ How It Works

1. **Edit `Vault_Radar_input.json`**  
   - Add/remove leaks, tweak values, assign to languages, set severity/scenario, etc.

2. **Run the builder:**  
   ```bash
   chmod +x ../Vault_Radar_builder.sh
   ../Vault_Radar_builder.sh --output-path . --languages bash,python --scenario AWS --lint
Use --output-path . to place results in this folder.

Other flags:

--languages or --language to select which scripts to generate

--scenario to filter leaks (e.g., only "AWS")

--header-template/--footer-template for custom banners

--lint to run sanity_check.sh if available

--dry-run to preview only

--quiet for silent run

Outputs include:

Vault_Radar_trigger.sh (Bash with leaks)

Vault_Radar_trigger.py (Python with leaks)

Vault_Radar_trigger.js (Node.js with leaks)

Vault_Radar_trigger.Dockerfile (Dockerfile with leaks)

Vault_Radar_trigger.tf (Terraform with leaks)

Vault_Radar_leaks_report.md (Markdown table report)

Vault_Radar_build.log (build log)

Vault_Radar_cleanup.sh (removes all generated files)

sanity_check_report.md (optional, if lint used)

Scan with your preferred security tool.

These files are intentionally full of "leaks" for demo/testing!

Cleanup after your demo:

./Vault_Radar_cleanup.sh

🚦 Example Usage

# Generate everything, using the AWS scenario
../Vault_Radar_builder.sh --output-path . --scenario AWS

# Bash and Python only, all scenarios, with lint
../Vault_Radar_builder.sh --output-path . --languages bash,python --lint

# Dry run, just preview what would be generated
../Vault_Radar_builder.sh --output-path . --languages node,terraform --dry-run

🔑 Customization
Add or remove leaks in Vault_Radar_input.json

Header/footer: edit files in templates/

Scenarios: filter for focused demos or workshops

Randomized output size for more/less realism

📝 Notes
These scripts are for demo and education only!

Don’t push real secrets/PII to public repositories.

Compatible with Vault Radar, TruffleHog, Gitleaks, and most SAST tools.

--

© 2024 Raymon Epping — Open-source demo for Vault Radar/secret scanning.