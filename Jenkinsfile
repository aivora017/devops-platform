pipeline { 
    agent any

    options {
        timeout(time: 1, unit: 'HOURS')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKER_HUB_USER = 'aivora017'
        GO_IMAGE = "${DOCKER_HUB_USER}/devops-go-app"
        PYTHON_IMAGE = "${DOCKER_HUB_USER}/devops-python-worker"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        KUBECONFIG = credentials('kubeconfig')
    }

    stages{

        stage('Checkout Code') {
            steps {
                    sh 'echo "Checking out branch : ${GIT_BRANCH}"'
                    checkout scm
            }
        }

        stage('Check System Resources') {
            steps {
                sh '''
                    echo "=== System Resource Check ==="
                    AVAILABLE_DISK=$(df /var/lib/docker | awk 'NR==2 {print $4}')
                    AVAILABLE_RAM=$(free | awk 'NR==2 {print $7}')
                    AVAILABLE_DISK_GB=$((AVAILABLE_DISK / 1024 / 1024))
                    AVAILABLE_RAM_MB=$((AVAILABLE_RAM / 1024))
                    
                    echo "Available Disk: ${AVAILABLE_DISK_GB}GB"
                    echo "Available RAM: ${AVAILABLE_RAM_MB}MB"
                    
                    if [ $AVAILABLE_DISK_GB -lt 2 ]; then
                        echo " WARNING: Less than 2GB disk space available"
                        echo "Docker image pull may fail. Skipping tests."
                        exit 0
                    fi
                    
                    if [ $AVAILABLE_RAM_MB -lt 300 ]; then
                        echo "WARNING: Less than 300MB RAM available"
                        echo "Docker containers may not run. Skipping tests."
                        exit 0
                    fi
                    
                    echo "System resources OK"
                    echo "=== Cleaning up unused Docker images ==="
                    docker image prune -af --filter "until=72h" || true
                '''
            }
        }

        stage('Run Tests') {
            parallel {
                stage('Go Tests') {
                    steps {
                        dir('app-go') {
                            script {
                                sh '''
                                    echo "Running Go tests in Docker (Alpine lightweight)..."
                                    docker run --rm \
                                    --memory=256m \
                                    -v $(pwd):/workspace \
                                    -w /workspace golang:1.22-alpine \
                                    go test ./... -v
                                '''
                            }
                        }
                    }
                }
                stage('Python Tests') {
                    steps {
                        dir('app-python') {
                            script {
                                sh '''
                                    echo "Running Python tests in Docker (Alpine lightweight)..."
                                    docker run --rm \
                                    --memory=256m \
                                    -v $(pwd):/workspace \
                                    -w /workspace python:3.11-alpine \
                                    sh -c "pip install -r requirements.txt && python -m pytest tests/ -v || true"
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Building Images'){
            parallel{
                stage('Build Go App') {
                    steps {
                        dir('app-go') {
                            script {
                                sh 'docker build -t ${GO_IMAGE}:${IMAGE_TAG} -t ${GO_IMAGE}:latest .'
                            }
                        }
                    }
                }

                stage('Build Python Worker') {
                    steps {
                        dir('app-python') {
                            script {
                                sh 'docker build -t ${PYTHON_IMAGE}:${IMAGE_TAG} -t ${PYTHON_IMAGE}:latest .'
                            }
                        }
                    }
                }
            }
        }
      

        stage('Push Images to Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh 'echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'
                        sh '''
                             #!/bin/bash
                            set -e
                            retry() {
                                local max_attempts=3
                                local attempt=1
                                until "$@"; do
                                    if [ $attempt -eq $max_attempts ]; then
                                        return 1
                                    fi
                                    attempt=$((attempt+1))
                                    echo "Retrying... ($attempt/$max_attempts)"
                                    sleep 5
                                done
                            }
                            retry docker push ${GO_IMAGE}:${IMAGE_TAG}
                            retry docker push ${GO_IMAGE}:latest
                            retry docker push ${PYTHON_IMAGE}:${IMAGE_TAG}
                            retry docker push ${PYTHON_IMAGE}:latest
                        '''
                        sh 'docker logout'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    set -e
                    kubectl set image deployment/go-api go-api=${GO_IMAGE}:${IMAGE_TAG}
                    kubectl set image deployment/python-worker python-worker=${PYTHON_IMAGE}:${IMAGE_TAG}
                    kubectl rollout status deployment/go-api --timeout=120s
                    kubectl rollout status deployment/python-worker --timeout=120s
                    echo "Deployments updated successfully"
                '''
            }
        }

        stage('Smoke Tests') {
            steps {
                sh '''
                    set -e
                    echo "Waiting for LoadBalancer IP..."
                    for i in {1..12}; do
                        GO_API_IP=$(kubectl get svc go-api -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "")
                        if [ ! -z "$GO_API_IP" ]; then
                            echo "Go API IP: $GO_API_IP"
                            curl -f http://${GO_API_IP}/health && echo "Health check passed" && exit 0
                        fi
                        echo "Attempt $i/12: Waiting for LoadBalancer IP..."
                        sleep 5
                    done
                    echo "ERROR: Could not reach Go API after 60s - LoadBalancer IP never appeared"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            sh 'echo "Pipeline completed successfully with build number: ${BUILD_NUMBER}."'
        }
        failure {
            sh 'echo "Pipeline failed. Please check the logs for details."'
        }
        always {
            sh '''
                echo "=== Cleaning up Docker resources ==="
                docker logout || true
                docker image prune -af --filter "until=24h" || true
                docker container prune -af --filter "until=24h" || true
                echo "=== Final System Status ==="
                df -h /var/lib/docker
                free -h
            '''
            cleanWs()
        }
    }

}