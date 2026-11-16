COMPOSE := docker --context rootless compose

.PHONY: start stop

start:
	@docker --context rootless info >/dev/null 2>&1 || { echo "ERROR: Docker rootless daemon is not running."; exit 1; }
	@docker --context rootless info --format '{{json .SecurityOptions}}' | grep -q rootless || { echo "ERROR: Docker daemon is not running in rootless mode."; exit 1; }
	@$(COMPOSE) pull --ignore-buildable
	@$(COMPOSE) up -d --build --remove-orphans

stop:
	@docker --context rootless info >/dev/null 2>&1 || { echo "ERROR: Docker rootless daemon is not running."; exit 1; }
	@$(COMPOSE) stop
