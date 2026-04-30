# Variables
COMPOSE=docker compose
APP_NAME=mon-app-python

.PHONY: help up down ps logs test sonar

help:
	@echo "Usage:"
	@echo "  make up      - Démarre tous les services (App, Jenkins, SonarQube)"
	@echo "  make down    - Arrête tous les services"
	@echo "  make ps      - Affiche l'état des services"
	@echo "  make logs    - Affiche les logs en temps réel"
	@echo "  make test    - Lance les tests unitaires dans un conteneur éphémère"
	@echo "  make sonar   - Lance un scan SonarQube en local via Docker"

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

test:
	$(COMPOSE) run --rm web python -m unittest test_app.py

sonar:
	$(COMPOSE) run --rm sonar-scanner \
		-Dsonar.login=admin \
		-Dsonar.password=admin \
		-Dsonar.projectKey=mon-app-python
