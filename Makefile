.PHONY: test integration-test slow-test check-plugin

# Fast tests: plugin load check + qualitative skill-content questions (~3-5 min)
test: check-plugin
	@tests/claude-code/run-all.sh

# Integration tests only: full headless Claude sessions with real registry (~10-15 min)
integration-test: check-plugin
	@echo ""
	@echo "=== Integration tests ==="
	@tests/notify-service/run-test.sh
	@tests/notify-service/run-brainstorm-with-external.sh
	@tests/import-external-spec/run-test.sh
	@tests/import-external-spec/run-grpc-import.sh
	@tests/api-spec-publish-integration/run-test.sh
	@tests/api-change-guardian-integration/run-test.sh
	@tests/api-contract-check-integration/run-test.sh
	@echo ""
	@echo "All integration tests passed."

# All tests: fast + integration
slow-test: test integration-test

# Verify the plugin loads and its skills are visible — run before anything else
check-plugin:
	@tests/check-plugin-loaded.sh
