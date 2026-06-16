pipeline{
    agent any 
    environment {
        AWS_REGION = "ap-southeast-1"
        AWS_ACCOUNT_ID  = credentials("aws-account-id")
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/blue-green-lab"
        IMAGE_TAG       = "${env.BUILD_NUMBER}"              
        ALB_NAME =  "blue-green-alb"
        CLUSTER  = "blue-green-cluster"

}
    stages{
        stage("check out")
        {
            steps{
                checkout scm
                echo "build number: ${BUILD_NUMBER} "
            }
        }
        stage("build imgaes")
        {
            steps{
                sh """
                        docker build \
                            --build-arg BUILD_NUMBER=${IMAGE_TAG} \
                            -t ${ECR_REPO}:${IMAGE_TAG} .
                    """
                echo "Built : ${ECR_REPO}:${IMAGE_TAG}"
            }
            }
        stage("push images")
        {
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
    }

}