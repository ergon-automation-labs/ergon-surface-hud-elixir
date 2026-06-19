.PHONY: run deps compile clean help setup setup-hooks init release publish-release docker-build docker-up docker-down

help:
	@echo "Mentra Glass - Bot Army Web Surface"
	@echo ""
	@echo "Setup (run once in a new clone):"
	@echo "  make setup       - git init (if needed), deps, install githooks"
	@echo "  make setup-hooks - Install git hooks (core.hooksPath = git-hooks)"
	@echo ""
	@echo "Development:"
	@echo "  make deps    - mix deps.get"
	@echo "  make run     - mix run --no-halt (PORT via env or config default)"
	@echo "  make clean   - mix clean"
	@echo ""
	@echo "Docker (for multi-app bundling):"
	@echo "  make docker-build - Build Docker image (release inside container)"
	@echo "  make docker-up    - Start containers (docker-compose up)"
	@echo "  make docker-down  - Stop containers (docker-compose down)"
	@echo ""
	@echo "Release (normally via git pre-push):"
	@echo "  make release         - Build OTP release"
	@echo "  make publish-release - Build, tarball, and publish to GitHub"
	@echo ""

setup: init deps setup-hooks
	@echo "✓ Setup complete. Run 'make run' to start; push to main to build and publish release."

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	mix deps.get

run: deps
	mix run --no-halt

clean:
	mix clean

release:
	MIX_ENV=prod mix release --overwrite
	@echo "✓ Release built in _build/prod/rel/"

publish-release: release
	@echo "Publishing to GitHub..."
	@RELEASE_NAME="ergon_surface_mentra_glass_elixir"; \
	VERSION=$$(cat _build/prod/rel/$$RELEASE_NAME/releases/start_erl.data | awk '{print $$2}'); \
	tar -czf $$RELEASE_NAME-$$VERSION.tar.gz -C _build/prod/rel $$RELEASE_NAME/; \
	gh release create v$$VERSION $$RELEASE_NAME-$$VERSION.tar.gz --draft=false; \
	echo "✓ Published v$$VERSION"

docker-build:
	docker-compose build
	@echo "✓ Docker image built"

docker-up:
	docker-compose up -d
	@echo "✓ Containers started (run 'make docker-down' to stop)"

docker-down:
	docker-compose down
	@echo "✓ Containers stopped"
