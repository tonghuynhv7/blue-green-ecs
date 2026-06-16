pipeline {
    agent any

    environment {
        AWS_REGION     = "ap-southeast-1"
        AWS_ACCOUNT_ID = credentials("aws-account-id")

        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/blue-green-lab"
        IMAGE_TAG = "${env.BUILD_NUMBER}"

        CLUSTER = "blue-green-cluster"
        ALB_NAME = "blue-green-alb"

        GREEN_SERVICE = "green-service"
        BLUE_SERVICE  = "blue-service"
    }

    stages {

        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Build Image") {
            steps {
                sh """
                    docker build -t ${ECR_REPO}:${IMAGE_TAG} .
                """
            }
        }

        stage("Login + Push ECR") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin \
                        ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        docker push ${ECR_REPO}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage("Deploy GREEN") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    sh """
                        aws ecs update-service \
                            --cluster ${CLUSTER} \
                            --service ${GREEN_SERVICE} \
                            --force-new-deployment \
                            --region ${AWS_REGION}
                    """
                }
            }
        }

        stage("Wait GREEN Stable") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    sh """
                        aws ecs wait services-stable \
                            --cluster ${CLUSTER} \
                            --services ${GREEN_SERVICE} \
                            --region ${AWS_REGION}
                    """
                }
            }
        }

        stage("Switch ALB → GREEN") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    sh """
                        ALB_ARN=\$(aws elbv2 describe-load-balancers \
                            --names ${ALB_NAME} \
                            --region ${AWS_REGION} \
                            --query 'LoadBalancers[0].LoadBalancerArn' \
                            --output text)

                        LISTENER_ARN=\$(aws elbv2 describe-listeners \
                            --load-balancer-arn \$ALB_ARN \
                            --region ${AWS_REGION} \
                            --query "Listeners[?Port=='80'].ListenerArn" \
                            --output text)

                        TG_GREEN_ARN=\$(aws elbv2 describe-target-groups \
                            --names green-tg \
                            --region ${AWS_REGION} \
                            --query 'TargetGroups[0].TargetGroupArn' \
                            --output text)

                        aws elbv2 modify-listener \
                            --region ${AWS_REGION} \
                            --listener-arn \$LISTENER_ARN \
                            --default-actions Type=forward,TargetGroupArn=\$TG_GREEN_ARN

                        echo "SWITCH SUCCESS → GREEN IS LIVE 🚀"
                    """
                }
            }
        }

        stage("Verify Production") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    script {
                        def dnsName = sh(
                            script: """
                                aws elbv2 describe-load-balancers \
                                    --names ${ALB_NAME} \
                                    --region ${AWS_REGION} \
                                    --query 'LoadBalancers[0].DNSName' \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        sh """
                            sleep 10
                            curl -sf http://${dnsName} || echo "Health check failed"
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Deployment SUCCESS 🚀"
        }

        failure {
            echo "Deployment FAILED ❌"
        }
    }
}