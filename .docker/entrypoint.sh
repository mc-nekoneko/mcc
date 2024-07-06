#!/bin/bash
cd /home/minecraft

java -version

STARTUP_COMMAND="java -Xms${SERVER_MEMORY} -Xmx${SERVER_MEMORY} ${JVM_FLAGS} -jar ${SERVER_JARFILE} ${SERVER_ARGS}"

terminate() {
  echo "Received SIGTERM, shutting down..."
  JAVA_PID=$(ps aux | grep '[j]ava' | awk '{print $2}')
  kill -SIGTERM "$JAVA_PID"
}

trap terminate SIGTERM

echo "Running command: ${STARTUP_COMMAND}"
eval ${STARTUP_COMMAND}
