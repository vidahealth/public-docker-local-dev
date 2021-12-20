#!/bin/bash
RUNNING_SERVICES=$(docker-compose ps --services --filter "status=running")
ALL_SERVICES=$(docker-compose ps --services)
MISSING_SERVICES=$(diff <(echo "${RUNNING_SERVICES}") <(echo "${ALL_SERVICES}"))
if [[ -z "${MISSING_SERVICES}" ]]; then
  echo "all services running"
else
  echo "Some service(s) failed to start"
  echo "${MISSING_SERVICES}"
  echo "Running services:"
  echo "${RUNNING_SERVICES}"
  echo "All services:"
  echo "${ALL_SERVICES}"
  echo "Printing logs from stopped services"
  STOPPED_SERVICES=$(docker-compose ps --services --all --filter "status=stopped" | xargs)
  sh -c "docker-compose logs --tail=200 ${STOPPED_SERVICES}"
  exit 1
fi
