#!/bin/bash
#Constants

REGION=us-east-1
REPOSITORY_NAME=sandbox
CLUSTER=pipelinecluster
family_wth_space=`sed -n 's/.*"family": "\(.*\)",/\1/p' /var/lib/jenkins/workspace/samplePipe/pipelinetask.json`
FAMILY="${family_wth_space// /}"
name_with_space=`sed -n 's/.*"name": "\(.*\)",/\1/p' /var/lib/jenkins/workspace/samplePipe/pipelinetask.json`
NAME="${name_with_space// /}"
SERVICE_NAME=pipelineservice


#Store the repositoryUri as a variable
REPOSITORY_URI=`aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} | jq .repositories[].repositoryUri | tr -d '"'`
echo $REPOSITORY_URI

#Replace the build number and respository URI placeholders with the constants above
sed -e "s;%BUILD_NUMBER%;${BUILD_NUMBER};g" -e "s;%REPOSITORY_URI%;${REPOSITORY_URI};g" /var/lib/jenkins/workspace/samplePipe/pipelinetask.json > "pipelineFile-v_${BUILD_NUMBER}.json"

chmod 777 pipelineFile-v_${BUILD_NUMBER}.json

#Register the task definition in the repository
aws ecs register-task-definition --family ${FAMILY} --cli-input-json file://pipelineFile-v_${BUILD_NUMBER}.json --region ${REGION}

SERVICES=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`

#Get latest revision
REVISION=`aws ecs describe-task-definition --task-definition ${FAMILY} --region ${REGION} | jq .taskDefinition.revision`

echo $REVISION
#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
  fi
  aws ecs update-service --cluster ${CLUSTER} --region ${REGION} --service ${SERVICE_NAME} --task-definition ${FAMILY}:${REVISION} --desired-count ${DESIRED_COUNT}
else
  echo "entered new service"
  aws ecs create-service --service-name ${SERVICE_NAME} --desired-count 1 --task-definition ${FAMILY} --cluster ${CLUSTER} --region ${REGION}
fi

