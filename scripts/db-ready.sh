#!/bin/bash

RESULT=`docker container inspect -f '{{.State.Status}}' sqlui_db 2>/dev/null`
if [ "$RESULT" != "running" ]; then
  docker compose up -d db-ready
fi
