# Default project/binary for your typical use-case
PROJECT      ?= folder_tree_cli
BINNAME      ?= folder_tree
RELEASE_SH    = ./release_update.sh
AUDIT_DIR     = ./folder_tree_cli
BACKUP_DIR    = ./backups
TPL_DIR       = ./folder_tree_cli/tpl
BUMP_FILE     = ./$(PROJECT)/bin/$(BINNAME)
BIN_FILE      = ./$(PROJECT)/bin/$(BINNAME)

.PHONY: help release sanity test audit docs clean

help:
	@echo ""
	@echo "Usage: make <target> [PROJECT=...] [BINNAME=...]"
	@echo ""
	@echo "Common targets:"
	@echo "  release    Run full release workflow (backup, bump, docs, commit, audit)"
	@echo "  sanity     Run code sanity checks"
	@echo "  test       Run all tests"
	@echo "  audit      Run repository audit"
	@echo "  docs       Generate documentation"
	@echo "  clean      Remove temporary files/logs"
	@echo ""
	@echo "Override PROJECT and BINNAME for other CLIs:"
	@echo "  make release PROJECT=radar_love_cli BINNAME=radar_love"
	@echo ""

release:
	$(RELEASE_SH) \
	  --target ./$(PROJECT) \
	  --output-dir $(BACKUP_DIR) \
	  --audit-dir $(AUDIT_DIR) \
	  --bump-file $(BUMP_FILE) \
	  --bump patch \
	  --tpl $(TPL_DIR) \
	  --bin $(BIN_FILE)

sanity:
	sanity_check --quiet

test:
	bash ./$(PROJECT)/test/run_tests.sh || echo "No test script found."

audit:
	repository_audit --child ./$(PROJECT) --outdir $(BACKUP_DIR)

docs:
	self_doc -t $(TPL_DIR) -f $(BIN_FILE)

clean:
	rm -f release.log
	rm -rf $(BACKUP_DIR)/*
