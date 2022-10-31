#!/bin/bash
docker stop log4jappenderdemo
docker container rm log4jappenderdemo
docker build -t log4jappenderdemo .
docker run -p 8080:8080 -d --name log4jappenderdemo log4jappenderdemo

