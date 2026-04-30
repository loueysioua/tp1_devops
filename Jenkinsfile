pipeline {
    agent any

    environment {
        IMAGE_NAME = "loueysioua/mon-app-devops"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Récupération du code source depuis Git...'
                checkout scm
            }
        }

        stage('Build & Tests Unitaires') {
            agent {
                docker {
                    image 'python:3.11-alpine'
                    reuseNode true
                }
            }
            steps {
                echo 'Installation des dépendances et exécution des tests...'
                sh 'pip install --no-cache-dir -r requirements.txt'
                sh 'python -m unittest discover'
            }
        }

        stage('Analyse Statique (SonarQube)') {
            steps {
                // withSonarQubeEnv injecte SONAR_HOST_URL et SONAR_AUTH_TOKEN
                withSonarQubeEnv('sonarqube') {
                    script {
                        def network = sh(
                            returnStdout: true,
                            script: "docker network ls --format '{{.Name}}' | grep 'app.network' | head -1"
                        ).trim()

                        echo "Réseau détecté : ${network}"

                        // On appelle docker run directement — bypasse complètement
                        // le plugin docker-workflow qui écrase les args réseau
                        sh """
                            docker run --rm \
                                --network ${network} \
                                -v "${env.WORKSPACE}:/usr/src" \
                                -e SONAR_HOST_URL="${env.SONAR_HOST_URL}" \
                                -e SONAR_TOKEN="${env.SONAR_AUTH_TOKEN}" \
                                sonarsource/sonar-scanner-cli:latest
                        """
                    }
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