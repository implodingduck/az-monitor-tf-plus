#!/bin/bash
docker stop appinsightsjavademo
docker container rm appinsightsjavademo
docker build -t appinsightsjavademo .
docker run -p 8080:8080 -d --name appinsightsjavademo appinsightsjavademo

