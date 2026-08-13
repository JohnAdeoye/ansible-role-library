ROLE ?=
VENV := .venv
BIN  := $(VENV)/bin

.PHONY: help deps lint test converge destroy clean

help:
	@echo "make deps            install python deps and ansible collections"
	@echo "make lint            yamllint + ansible-lint"
	@echo "make test            molecule test (all roles, or ROLE=<name>)"
	@echo "make converge        molecule converge, leaves containers running"
	@echo "make destroy         tear down molecule containers"

$(VENV):
	python3 -m venv $(VENV)

deps: $(VENV)
	$(BIN)/pip install --quiet --upgrade pip
	$(BIN)/pip install --quiet -r requirements.txt
	$(BIN)/ansible-galaxy collection install -r requirements.yml

lint:
	$(BIN)/yamllint .
	$(BIN)/ansible-lint

# With ROLE set, test one role; otherwise walk every role that has a scenario.
test:
ifdef ROLE
	cd roles/$(ROLE) && ../../$(BIN)/molecule test
else
	@for r in $$(ls roles); do \
		if [ -d "roles/$$r/molecule" ]; then \
			echo "=== molecule test: $$r ==="; \
			(cd roles/$$r && ../../$(BIN)/molecule test) || exit 1; \
		fi; \
	done
endif

converge:
	cd roles/$(ROLE) && ../../$(BIN)/molecule converge

destroy:
	cd roles/$(ROLE) && ../../$(BIN)/molecule destroy

clean:
	rm -rf $(VENV) .ansible_facts .cache patch-reports
	find . -name '*.retry' -delete
