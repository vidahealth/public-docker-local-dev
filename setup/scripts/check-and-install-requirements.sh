#!/bin/bash
set -e
printf "Checking for required pre-requisite command line tools...\n\n"

# homebrew
if [ -x "$(command -v brew)" ]; then
  echo "SUCCESS: brew is installed"
else
  echo "MISSING: You must install brew, please follow instructions at"
  echo "https://vidahealth.atlassian.net/wiki/spaces/WIKI/pages/744357970/Provisioning+a+new+Mac+for+development"
  exit 1
fi

# ngrok
if [ -x "$(command -v ngrok)" ]; then
  echo "SUCCESS: ngrok is installed"
else
  echo "ngrok not installed, installing now"
  brew install ngrok
  echo "MISSING: ngrok requires additional configuration with your auto token"
  echo "Please visit https://dashboard.ngrok.com/get-started/setup and log in with your google account"
  exit 1
fi

# gcloud command line
if [ -x "$(command -v gcloud)" ]; then
  echo "SUCCESS: gcloud is installed"
else
  echo "gcloud not installed, installing now"
  curl https://sdk.cloud.google.com | bash
  echo "SUCCESS: gcloud is now installed"
fi

# docker installation
if [ -x "$(command -v docker)" ]; then
  echo "SUCCESS: docker is installed"
else
  echo "MISSING: docker is not installed, please install following instructions at"
  echo "https://store.docker.com/editions/community/docker-ce-desktop-mac"
  exit 1
fi
