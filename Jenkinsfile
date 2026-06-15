// ============================================================
// Jenkinsfile — Blue-Green Deployment cho ECS Fargate
// Flow: GitHub → Build → Push ECR → Deploy Green
//       → Health Check → (Manual Approve) → Switch Traffic
// ============================================================

pipeline {
    agent any

    // ── Biến môi trường toàn pipeline ──────────────────────
    environment {
        AWS_REGION      = "ap-southeast-1"
        AWS_ACCOUNT_ID  = credentials('aws-account-id')      // Jenkins credential (Secret text)
        ECR_REPO        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/myapp-dev"
        IMAGE_TAG       = "${env.BUILD_NUMBER}"              // mỗi build = 1 tag mới
        APP_PORT        = "3000"

        // Tên resource phải khớp với Terraform output
        ECS_CLUSTER_GREEN  = "myapp-dev-green-cluster"
        ECS_SERVICE_GREEN  = "myapp-dev-green-service"
        ECS_CLUSTER_BLUE   = "myapp-dev-blue-cluster"
        ECS_SERVICE_BLUE   = "myapp-dev-blue-service"

        ALB_NAME        = "myapp-dev-alb"
        TF_DIR          = "${env.WORKSPACE}/terraform"   // nếu để Terraform cùng repo
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    // ── Trigger tự động khi có push lên main ───────────────
    triggers {
        githubPush()
    }

    // ── Parameters cho manual trigger ──────────────────────
    parameters {
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Bỏ qua bước chạy test (dùng khi hotfix)'
        )
        booleanParam(
            name: 'AUTO_SWITCH_TRAFFIC',
            defaultValue: false,
            description: 'Tự động switch traffic sau khi health check pass (không cần manual approve)'
        )
    }

    stages {

        // ── 1. Checkout ─────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    echo "Commit: ${env.GIT_COMMIT_SHORT} — ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        // ── 2. Test ─────────────────────────────────────────
        stage('Test') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                sh '''
                    npm ci
                    npm test
                '''
            }
            post {
                always {
                    // Publish test results nếu có junit output
                    junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                }
            }
        }

        // ── 3. Build Docker Image ────────────────────────────
        stage('Build Image') {
            steps {
                script {
                    env.FULL_IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
                    env.LATEST_IMAGE = "${ECR_REPO}:latest"

                    sh """
                        docker build \\
                            --build-arg NODE_ENV=production \\
                            --build-arg BUILD_NUMBER=${IMAGE_TAG} \\
                            -t ${env.FULL_IMAGE} \\
                            -t ${env.LATEST_IMAGE} \\
                            .
                    """
                    echo "Built: ${env.FULL_IMAGE}"
                }
            }
        }

        // ── 4. Push lên ECR ──────────────────────────────────
        stage('Push to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \\
                            docker login --username AWS --password-stdin \\
                            ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        docker push ${env.FULL_IMAGE}
                        docker push ${env.LATEST_IMAGE}

                        echo "Pushed: ${env.FULL_IMAGE}"
                    """
                }
            }
        }

        // ── 5. Deploy lên ECS Green ──────────────────────────
        stage('Deploy to Green') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    script {
                        // Lấy task definition hiện tại của Green
                        def currentTaskDef = sh(
                            script: """
                                aws ecs describe-services \\
                                    --region ${AWS_REGION} \\
                                    --cluster ${ECS_CLUSTER_GREEN} \\
                                    --services ${ECS_SERVICE_GREEN} \\
                                    --query 'services[0].taskDefinition' \\
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        echo "Current task def: ${currentTaskDef}"

                        // Lấy container definition JSON của task hiện tại
                        // rồi chỉ thay image tag mới
                        def newTaskDefArn = sh(
                            script: """
                                # Lấy task def JSON, thay image, register task def mới
                                TASK_DEF_JSON=\$(aws ecs describe-task-definition \\
                                    --region ${AWS_REGION} \\
                                    --task-definition ${currentTaskDef} \\
                                    --query 'taskDefinition' \\
                                    --output json)

                                NEW_TASK_DEF=\$(echo \$TASK_DEF_JSON | python3 -c "
import json, sys
td = json.load(sys.stdin)
# Thay image trong container đầu tiên
td['containerDefinitions'][0]['image'] = '${env.FULL_IMAGE}'
# Xóa các field không được phép khi register task def mới
for key in ['taskDefinitionArn','revision','status','requiresAttributes',
            'compatibilities','registeredAt','registeredBy']:
    td.pop(key, None)
print(json.dumps(td))
")

                                NEW_ARN=\$(aws ecs register-task-definition \\
                                    --region ${AWS_REGION} \\
                                    --cli-input-json "\$NEW_TASK_DEF" \\
                                    --query 'taskDefinition.taskDefinitionArn' \\
                                    --output text)

                                echo \$NEW_ARN
                            """,
                            returnStdout: true
                        ).trim()

                        echo "New task definition: ${newTaskDefArn}"
                        env.NEW_TASK_DEF_ARN = newTaskDefArn

                        // Update ECS Service Green với task def mới
                        sh """
                            aws ecs update-service \\
                                --region ${AWS_REGION} \\
                                --cluster ${ECS_CLUSTER_GREEN} \\
                                --service ${ECS_SERVICE_GREEN} \\
                                --task-definition ${env.NEW_TASK_DEF_ARN} \\
                                --force-new-deployment
                        """
                    }
                }
            }
        }

        // ── 6. Wait for Green stable ─────────────────────────
        stage('Wait Green Stable') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        echo "Waiting for Green service to stabilize..."
                        aws ecs wait services-stable \\
                            --region ${AWS_REGION} \\
                            --cluster ${ECS_CLUSTER_GREEN} \\
                            --services ${ECS_SERVICE_GREEN}

                        echo "Green is stable!"
                    """
                }
            }
        }

        // ── 7. Health Check Green qua ALB port 81 ────────────
        stage('Health Check Green') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    script {
                        def albDns = sh(
                            script: """
                                aws elbv2 describe-load-balancers \\
                                    --region ${AWS_REGION} \\
                                    --names ${ALB_NAME} \\
                                    --query 'LoadBalancers[0].DNSName' \\
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        env.ALB_DNS = albDns
                        echo "ALB DNS: ${albDns}"

                        // Health check Green qua port 81 (Tester endpoint)
                        def maxRetries = 10
                        def retryInterval = 15
                        def passed = false

                        for (int i = 1; i <= maxRetries; i++) {
                            def status = sh(
                                script: "curl -s -o /dev/null -w '%{http_code}' http://${albDns}:81/health",
                                returnStdout: true
                            ).trim()

                            echo "Attempt ${i}/${maxRetries} — HTTP ${status}"

                            if (status == '200') {
                                passed = true
                                break
                            }

                            if (i < maxRetries) sleep(retryInterval)
                        }

                        if (!passed) {
                            error("Health check FAILED after ${maxRetries} attempts!")
                        }

                        echo "Health check PASSED — Green is healthy on port 81"
                    }
                }
            }
        }

        // ── 8. Manual Approve (Tester xác nhận) ──────────────
        stage('Tester Approval') {
            when {
                expression { !params.AUTO_SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def userInput = input(
                        id: 'tester-approval',
                        message: """
                            Green cluster đã sẵn sàng!
                            - Image: ${env.FULL_IMAGE}
                            - Commit: ${env.GIT_COMMIT_SHORT}
                            - Test URL: http://${env.ALB_DNS}:81

                            Tester đã xác nhận xong chưa?
                        """,
                        ok: 'Switch Traffic → Production',
                        submitter: 'tester,developer,admin',
                        parameters: [
                            choice(
                                name: 'ACTION',
                                choices: ['switch', 'abort'],
                                description: 'switch = deploy Green lên production | abort = rollback'
                            )
                        ]
                    )

                    if (userInput == 'abort') {
                        error("Deployment aborted by tester!")
                    }
                }
            }
        }

        // ── 9. Switch Traffic: port 80 → Green ───────────────
        stage('Switch Traffic to Green') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    script {
                        // Lấy ARN của listener port 80
                        def listenerArn = sh(
                            script: """
                                ALB_ARN=\$(aws elbv2 describe-load-balancers \\
                                    --region ${AWS_REGION} \\
                                    --names ${ALB_NAME} \\
                                    --query 'LoadBalancers[0].LoadBalancerArn' \\
                                    --output text)

                                aws elbv2 describe-listeners \\
                                    --region ${AWS_REGION} \\
                                    --load-balancer-arn \$ALB_ARN \\
                                    --query "Listeners[?Port==\`80\`].ListenerArn" \\
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        // Lấy ARN của TG Green
                        def tgGreenArn = sh(
                            script: """
                                aws elbv2 describe-target-groups \\
                                    --region ${AWS_REGION} \\
                                    --names myapp-dev-tg-green \\
                                    --query 'TargetGroups[0].TargetGroupArn' \\
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        // Swap listener 80 → TG Green
                        sh """
                            aws elbv2 modify-listener \\
                                --region ${AWS_REGION} \\
                                --listener-arn ${listenerArn} \\
                                --default-actions Type=forward,TargetGroupArn=${tgGreenArn}

                            echo "Traffic switched: port 80 → GREEN"
                        """

                        env.TG_GREEN_ARN = tgGreenArn
                        env.LISTENER_ARN = listenerArn
                    }
                }
            }
        }

        // ── 10. Verify Production ─────────────────────────────
        stage('Verify Production') {
            steps {
                script {
                    sleep(10) // Chờ ALB cập nhật routing
                    def status = sh(
                        script: "curl -s -o /dev/null -w '%{http_code}' http://${env.ALB_DNS}/health",
                        returnStdout: true
                    ).trim()

                    if (status != '200') {
                        error("Production health check FAILED after switch! HTTP ${status}")
                    }

                    echo "Production verified — HTTP ${status} ✓"
                }
            }
        }

    } // end stages

    // ── Post actions ────────────────────────────────────────
    post {
        success {
            echo """
            ╔══════════════════════════════════════╗
            ║  Deployment SUCCESS                  ║
            ║  Image : ${env.FULL_IMAGE}
            ║  Commit: ${env.GIT_COMMIT_SHORT}     ║
            ║  URL   : http://${env.ALB_DNS}        ║
            ╚══════════════════════════════════════╝
            """
        }

        failure {
            // Auto rollback: trỏ port 80 về TG Blue
            script {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        echo "Pipeline FAILED — attempting rollback to Blue..."

                        ALB_ARN=\$(aws elbv2 describe-load-balancers \\
                            --region ${AWS_REGION} \\
                            --names ${ALB_NAME} \\
                            --query 'LoadBalancers[0].LoadBalancerArn' \\
                            --output text)

                        LISTENER_ARN=\$(aws elbv2 describe-listeners \\
                            --region ${AWS_REGION} \\
                            --load-balancer-arn \$ALB_ARN \\
                            --query "Listeners[?Port==\`80\`].ListenerArn" \\
                            --output text)

                        TG_BLUE_ARN=\$(aws elbv2 describe-target-groups \\
                            --region ${AWS_REGION} \\
                            --names myapp-dev-tg-blue \\
                            --query 'TargetGroups[0].TargetGroupArn' \\
                            --output text)

                        aws elbv2 modify-listener \\
                            --region ${AWS_REGION} \\
                            --listener-arn \$LISTENER_ARN \\
                            --default-actions Type=forward,TargetGroupArn=\$TG_BLUE_ARN

                        echo "Rolled back to Blue"
                    """
                }
            }
        }

        cleanup {
            // Xóa image local để tiết kiệm disk trên Jenkins agent
            sh """
                docker rmi ${env.FULL_IMAGE} || true
                docker rmi ${env.LATEST_IMAGE} || true
                docker system prune -f || true
            """
        }
    }
}
