#!/bin/bash
# This script should be run every time you modify the environment-config.yaml

# It uses the Jinja2 Templating language to generate a couple configuration files we need
# https://jinja.palletsprojects.com/en/master/templates/
# We need to do this, so that we can correctly configure our nginx proxy, environment variables,
# and docker-compose file to handle different network addresses and ports for services if they run
# through docker-compose or locally on your laptop, or if they aren't running at all.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "updating configurations with latest values from environment-config.yaml"
mkdir -p "${DIR}/compose-service-configs/generated/"

set -e -x
docker run --rm --mount type=bind,source=${DIR},target=/usr/src/app rmelickvida/jinja2-cli:1de0a4a jinja2 setup/jinja-templates/.env.jinja environment-config.yaml --format=yaml > "${DIR}/.env"
docker run --rm --mount type=bind,source=${DIR},target=/usr/src/app rmelickvida/jinja2-cli:1de0a4a jinja2 setup/jinja-templates/docker-compose.yaml.jinja environment-config.yaml --format=yaml > "${DIR}/docker-compose.yaml"
docker run --rm --mount type=bind,source=${DIR},target=/usr/src/app rmelickvida/jinja2-cli:1de0a4a jinja2 setup/jinja-templates/vida-proxy.conf.template.jinja environment-config.yaml --format=yaml > "${DIR}/compose-service-configs/generated/vida-proxy.conf.template"
docker run --rm --mount type=bind,source=${DIR},target=/usr/src/app rmelickvida/jinja2-cli:1de0a4a jinja2 setup/jinja-templates/ngrok.yml.jinja environment-config.yaml --format=yaml > "${DIR}/ngrok.yml"
