pipeline { 
    agent any

    environment {
        DOCKER_HUB_USER = 'aivora017'
        GO_IMAGE = "${DOCKER_HUB_USER}/devops-go-app"
        PYTHON_IMAGE = "${DOCKER_HUB_USER}/devops-python-worker"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        AWS_REGION = 'ap-southeast-2'
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    echo "Building Go image"
                    docker build -t ${GO_IMAGE}:${IMAGE_TAG} -t ${GO_IMAGE}:latest -f docker/go/Dockerfile app-go/
                    
                    echo "Building Python worker image"
                    docker build -t ${PYTHON_IMAGE}:${IMAGE_TAG} -t ${PYTHON_IMAGE}:latest -f docker/python/Dockerfile app-python/
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "Pushing images to Docker Hub"
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${GO_IMAGE}:${IMAGE_TAG}
                        docker push ${GO_IMAGE}:latest
                        docker push ${PYTHON_IMAGE}:${IMAGE_TAG}
                        docker push ${PYTHON_IMAGE}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to AWS EKS') {
            steps {
                sh '''
                    echo "Deploying to EKS"
                    kubectl apply -f k8s/aws/namespace.yaml
                    kubectl apply -f k8s/aws/go-api-deployment.yaml
                    kubectl apply -f k8s/aws/python-worker-deployment.yaml
                    kubectl apply -f k8s/aws/hpa.yaml
                    kubectl set image deployment/go-api go-api=${GO_IMAGE}:${IMAGE_TAG} -n devops
                    kubectl set image deployment/python-worker python-worker=${PYTHON_IMAGE}:${IMAGE_TAG} -n devops
                    echo "Waiting for rollouts"
                    kubectl rollout status deployment/go-api -n devops --timeout=2m || true
                    kubectl rollout status deployment/python-worker -n devops --timeout=2m || true
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    echo "Running health check"
                    sleep 10
                    
                    GO_POD=$(kubectl get pods -n devops -l app=go-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                    if [ ! -z "$GO_POD" ]; then
                        echo "Go API pod: $GO_POD"
                        kubectl logs $GO_POD -n devops | head -5 || true
                    else
                        echo "Go API pod not found yet"
                    fi
                    
                    PYTHON_POD=$(kubectl get pods -n devops -l app=python-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                    if [ ! -z "$PYTHON_POD" ]; then
                        echo "Python worker pod: $PYTHON_POD"
                        kubectl logs $PYTHON_POD -n devops | head -5 || true
                    else
                        echo "Python worker pod not found yet"
                    fi
                '''
            }
        }
    }

    post {
        always {
            echo "Build pipeline completed"
        }
        failure {
            echo "Pipeline failed"
        }
    }
}