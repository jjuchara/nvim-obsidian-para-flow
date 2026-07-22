NVIM ?= nvim
STYLUA ?= stylua
SELENE ?= selene
TEST_VAULT ?=

.PHONY: test lint format helptags check test-integration

test:
	$(NVIM) --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run()"

lint:
	$(SELENE) .lazy.lua lua plugin tests
	$(STYLUA) --check .lazy.lua lua plugin tests
	sh -n scripts/nvim-dev
	sh -n tests/manual/bin/obsidian
	sh tests/dev_launcher_spec.sh

format:
	$(STYLUA) .lazy.lua lua plugin tests

helptags:
	$(NVIM) --headless --clean -u NONE "+helptags doc" +qa

check: lint test helptags

test-integration:
	@test -n "$(TEST_VAULT)" || { echo "TEST_VAULT is required; refusing to access any vault" >&2; exit 2; }
	OBSIDIAN_PARA_TEST_VAULT="$(TEST_VAULT)" $(NVIM) --headless --clean -u tests/integration_init.lua -c "lua MiniTest.run({ collect = { find_files = function() return { 'tests/integration_spec.lua' } end } })"
