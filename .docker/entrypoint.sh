#!/bin/bash
cd /home/minecraft

java -version

STARTUP_COMMAND="java -Xms${SERVER_MEMORY} -Xmx${SERVER_MEMORY} ${JVM_FLAGS} -jar ${SERVER_JARFILE} ${SERVER_ARGS}"

echo "Running command: ${STARTUP_COMMAND}"
eval ${STARTUP_COMMAND}
