pipleline{
    agent any 
    enviroment {
        AWS_REGION = "ap-southeast-1"
        AWS_ACCOUNT_ID  = credentials("aws-account-id")
        ECR_REPO = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/blue-green-lab
        IMAGE_TAG       = "${env.BUILD_NUMBER}"              // mỗi build = 1 tag mới
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
    }

}