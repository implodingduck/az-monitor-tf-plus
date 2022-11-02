#!/bin/bash
source ../.env
docker stop log4jappenderdemo
docker container rm log4jappenderdemo
docker build -t log4jappenderdemo .
docker run -p 8080:8080 -d -e LAW_ID=$LAW_ID -e SHARED_KEY=$SHARED_KEY -e FUNCTION_URL=$FUNCTION_URL -e FUNCTION_KEY=$FUNCTION_KEY --name log4jappenderdemo log4jappenderdemo

