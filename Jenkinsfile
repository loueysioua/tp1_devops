pipeline {
    agent any

    environment {
        IMAGE_NAME = "loueysioua/mon-app-devops"
        // Le nom du réseau créé par docker-compose.
        // Format : {nom_du_dossier_projet}_{nom_du_réseau}
        // Adaptez "tp1_devops" si votre dossier s'appelle différemment.
        APP_NETWORK = "tp1_devops_app-network"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source depuis Git...'
                checkout scm
            }
        }

        // ✅ Python s'exécute dans un conteneur éphémère : pas d'installation sur l'hôte
        stage('Build & Tests Unitaires') {
            agent {
                docker {
                    image 'python:3.11-alpine'
                    reuseNode true   // Utilise le même workspace que l'agent principal
                }
            }
            steps {
                echo 'Installation des dépendances et exécution des tests...'
                sh 'pip install --no-cache-dir -r requirements.txt'
                sh 'python -m unittest discover'
            }
        }

        // ✅ sonar-scanner s'exécute dans son propre conteneur officiel
        stage('Analyse Statique (SonarQube)') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:latest'
                    // Doit être sur le même réseau que le conteneur sonarqube
                    args "--network ${APP_NETWORK}"
                    reuseNode true
                }
            }
            steps {
                echo 'Analyse du code avec SonarQube...'
                withSonarQubeEnv('sonarqube') {
                    sh 'sonar-scanner'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo 'Vérification du Quality Gate...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ✅ Docker build/push s'exécute directement sur l'agent Jenkins
        //    qui a accès au socket Docker via le volume /var/run/docker.sock
        stage('Docker Build') {
            steps {
                echo "Construction de l'image Docker : ${IMAGE_NAME}:${BUILD_NUMBER}..."
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Docker Push') {
            steps {
                echo 'Publication sur Docker Hub...'
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials',
                                                 passwordVariable: 'DOCKER_PASSWORD',
                                                 usernameVariable: 'DOCKER_USERNAME')]) {
                    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'
                    sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }
    }

    post {
        always {
            echo 'Nettoyage : Déconnexion de Docker Hub...'
            sh 'docker logout'
        }
    }
}
