pipeline {
    // Exécute le pipeline sur n'importe quel agent Jenkins disponible
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

        stage('Build/Install') {
            steps {
                echo 'Installation des dépendances...'
                sh 'pip3 install --break-system-packages -r requirements.txt'
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Exécution des tests unitaires...'
                sh 'python3 -m unittest discover'
            }
        }

        stage('Static Analysis') {
            steps {
                echo 'Analyse du code avec SonarQube...'
                script {
                    // Si sonar-scanner est configuré comme un outil Jenkins (Global Tool Configuration)
                    // on peut l'appeler ainsi. Sinon, on utilise la commande directe.
                    // def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv('sonarqube') {
                        sh 'sonar-scanner'
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
                echo "Construction de l'image Docker avec le tag ${BUILD_NUMBER}..."
                // On tague l'image avec le numéro de build Jenkins ET avec 'latest'
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                sh "docker build -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Docker Push') {
            steps {
                echo 'Connexion à Docker Hub et publication...'
                // withCredentials masque le mot de passe dans les logs Jenkins
                // 'docker-hub-credentials' est l'ID que tu as créé à l'Étape 1
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials',
                                                 passwordVariable: 'DOCKER_PASSWORD',
                                                 usernameVariable: 'DOCKER_USERNAME')]) {

                    // Connexion sécurisée via l'entrée standard (stdin)
                    sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'

                    // Si on arrive ici, c'est que les tests ont réussi (contrainte respectée)
                    sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }
    }

    // Le bloc post s'exécute toujours à la fin, peu importe le résultat
    post {
        always {
            echo 'Nettoyage : Déconnexion de Docker Hub...'
            sh 'docker logout'
        }
    }
}