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
	@echo "  make deploy-infra   - Déploie l'infrastructure (Terraform)"
	@echo "  make deploy-app     - Déploie l'application (Ansible)"
	@echo "  make smoke-test     - Effectue un smoke test sur l'application"

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

# ── DÉPLOIEMENT EN LOCAL (100% Dockerisé via KinD) ──

deploy-infra:
	@echo "🏗️  Création de l'infrastructure avec Terraform..."
	docker run --rm -it --entrypoint sh \
		-v "$(PWD)/terraform:/workspace" -w /workspace \
		-v /var/run/docker.sock:/var/run/docker.sock \
		hashicorp/terraform:latest -c "terraform init"
	docker run --rm -it --entrypoint sh \
		-v "$(PWD)/terraform:/workspace" -w /workspace \
		-v /var/run/docker.sock:/var/run/docker.sock \
		hashicorp/terraform:latest -c "terraform apply -auto-approve"

deploy-app:
	@echo "⚙️  Déploiement avec Ansible..."
	docker run --rm -it --network host \
		-v "$(PWD)/ansible:/workspace" -v "$(PWD)/k8s:/k8s" -w /workspace \
		-e K8S_AUTH_KUBECONFIG=/k8s/kubeconfig \
		willhallonline/ansible:latest sh -c "\
			pip install kubernetes && \
			ansible-playbook -i hosts.ini deploy.yml \
			--extra-vars 'image_tag=latest image_name=loueysioua/mon-app-devops k8s_namespace=production'"

smoke-test:
	@echo "💨 Lancement du Smoke Test..."
	@echo "Test de l'URL: http://localhost:8081"
	docker run --rm --network host curlimages/curl:latest -H "Host: mon-app.local" -s -o /dev/null -w "%{http_code}\n" --max-time 10 "http://localhost:8081"

deploy-monitoring:
	@echo "📊 Déploiement de Prometheus et Grafana via Helm..."
	docker run --rm -it --network host --entrypoint sh \
		-v "$(PWD)/monitoring:/workspace" -v "$(PWD)/k8s:/k8s" -w /workspace \
		-e KUBECONFIG=/k8s/kubeconfig \
		alpine/helm:latest -c "\
		helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && \
		helm repo update && \
		helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace -f prometheus-values.yml"
	@echo "🚨 Déploiement des règles d'alerting..."
	docker run --rm -it --network host \
		-v "$(PWD)/monitoring:/workspace" -v "$(PWD)/k8s:/k8s" -w /workspace \
		-e KUBECONFIG=/k8s/kubeconfig \
		bitnami/kubectl:latest apply -f alerting-rules.yml

pf-grafana:
	@echo "🔓 Ouverture du port Grafana (3000) sur localhost..."
	@echo "👉 Identifiants par défaut: admin / DevOps-TP-2024!"
	docker run --rm -it --network host \
		-v "$(PWD)/k8s:/k8s" -w /k8s \
		-e KUBECONFIG=/k8s/kubeconfig \
		bitnami/kubectl:latest port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

pf-prometheus:
	@echo "🔓 Ouverture du port Prometheus (9090) sur localhost..."
	docker run --rm -it --network host \
		-v "$(PWD)/k8s:/k8s" -w /k8s \
		-e KUBECONFIG=/k8s/kubeconfig \
		bitnami/kubectl:latest port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
