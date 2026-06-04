.PHONY: test integration-test slow-test check-plugin publish

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

# Bump marketplace SHA to current HEAD and push
publish:
	@echo "Updating marketplace SHA to $$(git rev-parse HEAD)..."
	@python3 -c "\
import json, subprocess, sys; \
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip(); \
path = '.claude-plugin/marketplace.json'; \
d = json.load(open(path)); \
d['plugins'][0]['version'] = subprocess.check_output(['git', 'describe', '--tags', '--always']).decode().strip(); \
json.dump(d, open(path, 'w'), indent=2); \
print('SHA: ' + sha)"
	@git add .claude-plugin/marketplace.json
	@git diff --cached --quiet || git commit -m "chore: bump marketplace to $$(git rev-parse --short HEAD)"
	@git push
	@echo "Done. Users can update with: claude plugin marketplace update superluminar-io && claude plugin update pinky-swear@superluminar-io"

# Verify the plugin loads and its skills are visible — run before anything else
check-plugin:
	@tests/check-plugin-loaded.sh
