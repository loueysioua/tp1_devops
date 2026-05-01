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
                sh 'pip install --no-cache-dir -r requirements.txt'
                sh 'python -m unittest discover'
            }
        }

        stage('Analyse Statique (SonarQube)') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    script {
                        // ── Debug : affiche toutes les variables injectées par withSonarQubeEnv ──
                        echo "SONAR_HOST_URL   = ${env.SONAR_HOST_URL}"
                        echo "SONAR_AUTH_TOKEN = ${env.SONAR_AUTH_TOKEN}"
                        echo "SONAR_TOKEN      = ${env.SONAR_TOKEN}"
                        echo "WORKSPACE        = ${env.WORKSPACE}"

                        def network = sh(
                            returnStdout: true,
                            script: "docker network ls --format '{{.Name}}' | grep 'app.network' | head -1"
                        ).trim()
                        echo "Réseau détecté : ${network}"

                        // Choisit le bon nom de variable token selon la version du plugin
                        def sonarToken = env.SONAR_AUTH_TOKEN ?: env.SONAR_TOKEN

                        // docker run avec stderr capturé pour voir les erreurs
                        sh """
                            set -x
                            docker run --rm \
                                --network ${network} \
                                -v "${env.WORKSPACE}:/usr/src" \
                                -w /usr/src \
                                -e SONAR_HOST_URL="${env.SONAR_HOST_URL}" \
                                -e SONAR_TOKEN="${sonarToken}" \
                                sonarsource/sonar-scanner-cli:latest \
                                sonar-scanner \
                                  -Dsonar.projectKey=mon-app-python \
                                  -Dsonar.sources=. \
                                  -Dsonar.host.url="${env.SONAR_HOST_URL}" \
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Docker Push') {
            steps {
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
            sh 'docker logout'
        }
    }
}