#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ngrok start -config ~/.ngrok2/ngrok.yml -config ${DIR}/ngrok.yml docker-local-dev
