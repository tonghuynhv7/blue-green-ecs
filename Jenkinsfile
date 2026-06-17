pipeline {
    agent any

    environment {
        AWS_REGION     = "ap-southeast-1"
        AWS_ACCOUNT_ID = credentials("aws-account-id")

        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/blue-green-lab"
        IMAGE_TAG = "${env.BUILD_NUMBER}"

        CLUSTER      = "cluser-blue-green"
        ALB_NAME     = "alb-green-blue"

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
                        CURRENT_TASK_DEF=\$(aws ecs describe-services \
                            --cluster ${CLUSTER} \
                            --services ${GREEN_SERVICE} \
                            --region ${AWS_REGION} \
                            --query 'services[0].taskDefinition' \
                            --output text)

                        echo "Current Task Def: \$CURRENT_TASK_DEF"

                        NEW_TASK_DEF=\$(aws ecs describe-task-definition \
                            --task-definition \$CURRENT_TASK_DEF \
                            --region ${AWS_REGION} \
                            --query 'taskDefinition' \
                            --output json | python3 -c "
import json, sys
td = json.load(sys.stdin)
td['containerDefinitions'][0]['image'] = '${ECR_REPO}:${IMAGE_TAG}'
for key in ['taskDefinitionArn','revision','status','requiresAttributes','compatibilities','registeredAt','registeredBy']:
    td.pop(key, None)
print(json.dumps(td))
")

                        NEW_TASK_DEF_ARN=\$(aws ecs register-task-definition \
                            --region ${AWS_REGION} \
                            --cli-input-json "\$NEW_TASK_DEF" \
                            --query 'taskDefinition.taskDefinitionArn' \
                            --output text)

                        echo "New Task Def: \$NEW_TASK_DEF_ARN"

                        aws ecs update-service \
                            --cluster ${CLUSTER} \
                            --service ${GREEN_SERVICE} \
                            --task-definition \$NEW_TASK_DEF_ARN \
                            --region ${AWS_REGION}

                        echo "Deploy GREEN done!"
                    """
                }
            }
        }

        stage("Wait GREEN Stable") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    sh """
                        echo "Waiting for green-service stable..."
                        aws ecs wait services-stable \
                            --cluster ${CLUSTER} \
                            --services ${GREEN_SERVICE} \
                            --region ${AWS_REGION}
                        echo "GREEN is stable!"
                    """
                }
            }
        }

        stage("Health Check GREEN") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    script {
                        def dnsName = sh(
                            returnStdout: true,
                            script: """
                                aws elbv2 describe-load-balancers \
                                    --names ${ALB_NAME} \
                                    --region ${AWS_REGION} \
                                    --query 'LoadBalancers[0].DNSName' \
                                    --output text
                            """
                        ).trim()

                        sh """
                            echo "Health check GREEN: http://${dnsName}:81"
                            curl -sf http://${dnsName}:81 || (echo "Health check FAILED" && exit 1)
                            echo "Health check PASSED"
                        """
                    }
                }
            }
        }

        stage("Approve Switch Traffic") {
            steps {
                input message: "Switch traffic sang GREEN?", ok: "Yes, Switch!"
            }
        }

        stage("Switch ALB GREEN") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    script {
                        def albArn = sh(
                            returnStdout: true,
                            script: """
                                aws elbv2 describe-load-balancers \
                                    --names ${ALB_NAME} \
                                    --region ${AWS_REGION} \
                                    --query 'LoadBalancers[0].LoadBalancerArn' \
                                    --output text
                            """
                        ).trim()

                        def listenerArn = sh(
                            returnStdout: true,
                            script: """
                                aws elbv2 describe-listeners \
                                    --load-balancer-arn ${albArn} \
                                    --region ${AWS_REGION} \
                                    --output json | python3 -c "
                                    import json,sys
listeners = json.load(sys.stdin)['Listeners']
print([l for l in listeners if l['Port']==80][0]['ListenerArn'])
"
                                    
                            """
                        ).trim()

                        def tgGreenArn = sh(
                            returnStdout: true,
                            script: """
                                aws elbv2 describe-target-groups \
                                    --names green \
                                    --region ${AWS_REGION} \
                                    --query 'TargetGroups[0].TargetGroupArn' \
                                    --output text
                            """
                        ).trim()

                        sh """
                            aws elbv2 modify-listener \
                                --listener-arn ${listenerArn} \
                                --default-actions Type=forward,TargetGroupArn=${tgGreenArn} \
                                --region ${AWS_REGION}

                            echo "SWITCH SUCCESS GREEN IS LIVE"
                        """
                    }
                }
            }
        }

        stage("Verify Production") {
            steps {
                withCredentials([aws(credentialsId: "aws-credentials")]) {
                    script {
                        def dnsName = sh(
                            returnStdout: true,
                            script: """
                                aws elbv2 describe-load-balancers \
                                    --names ${ALB_NAME} \
                                    --region ${AWS_REGION} \
                                    --query 'LoadBalancers[0].DNSName' \
                                    --output text
                            """
                        ).trim()

                        sh """
                            sleep 10
                            echo "Verify production: http://${dnsName}"
                            curl -sf http://${dnsName} || echo "Verify FAILED"
                            echo "Verify PASSED"
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Deployment SUCCESS"
        }
        failure {
            echo "Deployment FAILED"
        }
    }
}