#!/bin/bash
cd /home/minecraft

java -version

eval java -Xms${SERVER_MEMORY} -Xmx${SERVER_MEMORY} ${JVM_FLAGS} -jar ${SERVER_JARFILE} ${SERVER_ARGS}
