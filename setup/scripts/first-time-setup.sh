#!/bin/bash
# You should only need to run this script the first time you ever use this project
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="${DIR}/../.."

# check for all the command line tools we will want to call
if [[ "${CONTINUOUS_INTEGRATION}" == true ]]
then
  echo "skipping requirements checking on travis"
else
  "${DIR}/check-and-install-requirements.sh"
fi


if [[ $(gcloud config get-value account) ]]
then
  echo "Already logged in to gcloud"
else
  echo "logging in to gcloud command line"
  gcloud auth login
fi

gcloud auth configure-docker us.gcr.io,gcr.io


echo "Copying environment-config.yaml to environment-config.yaml"
docker run --rm --mount type=bind,source=${ROOT_DIR},target=/usr/src/app rmelickvida/jinja2-cli:1de0a4a jinja2 setup/jinja-templates/environment-config.yaml.jinja -D SAFE_USERNAME="${USER//.}" --format=yaml > "${ROOT_DIR}/environment-config.yaml"

echo "Generating templates from environment"
"${ROOT_DIR}/environment-update.sh"

echo "Starting up docker in 'detached' mode before initializing databases"
cd "${ROOT_DIR}" || exit
docker-compose up -d --remove-orphans

echo "Triggering database reset"
"${DIR}/reset-databases.sh"

echo "Restarting docker services"
docker-compose restart

if [[ "${CONTINUOUS_INTEGRATION}" == true ]]
then
  echo "skipping ngrok tunnel on travis"
else
  echo "Starting ngrok tunnel"
  "${ROOT_DIR}/ngrok-tunnel.sh"
fi
