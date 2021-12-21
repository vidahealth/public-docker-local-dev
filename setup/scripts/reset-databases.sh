#!/bin/bash
# This script
# * downloads the latest database dumps from the staging environment, creating a new dump if necessary
# * wipes out the databases in your local docker
# * re-initializes them with the downloaded data

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="${DIR}/../.."

function reset_docker_containers() {
  info "Stopping database containers and removing their volumes"

  set +e # ignore errors when cleaning up, in case the containers don't exist
  set -x # print out all the docker commands we run
  docker stop public-docker-local-dev_mysql_1
  docker rm public-docker-local-dev_mysql_1
  docker volume rm public-docker-local-dev_mysql-database
  docker stop public-docker-local-dev_postgres_1
  docker rm public-docker-local-dev_postgres_1
  docker volume rm public-docker-local-dev_postgres-database
  set +x
  set -e

  info "Restarting database containers"
  # run docker compose in a subshell, so we don't mess with this directory
  (cd "${ROOT_DIR}" || exit; docker-compose up -d mysql postgres )
  info "Sleeping for 30s to allow db startup"
  sleep 30

  return 0
}

function create_database_dump() {
  local DB_INSTANCE_NAME=${1}
  local PROJECT="${2:-gcp-project-name}"
  local BUCKET="${3:-gcp-project-name-docker-local-dev}"

  local CURRENT_TIME
  CURRENT_TIME=$(date -u +%FT%H:%M:%S)

  local EXTRA_PARAMS=""
  if [[ "${DB_INSTANCE_NAME}" == "XXX-postgres" ]]; then
    EXTRA_PARAMS="--database=staging"
  fi

  info "Triggering google cloudsql export of ${DB_INSTANCE_NAME}"
  set -x
  gcloud --project="${PROJECT}" sql export sql "${DB_INSTANCE_NAME}" "gs://${BUCKET}/${DB_INSTANCE_NAME}/${DB_INSTANCE_NAME}_export_${CURRENT_TIME}.sql.gz" --offload ${EXTRA_PARAMS}
  set +x

  return 0
}

function dump_all_databases() {
  # Update this function with your real database names and gcp project information
  info "Creating fresh database dumps in google cloud storage"
  create_database_dump XXX-mysql
  create_database_dump XXX-postgres
}

function ensure_latest_downloaded() {
  local DB_INSTANCE_NAME=${1}
  local PROJECT="${2:-gcp-project-name}"
  local BUCKET="${3:-gcp-project-name-docker-local-dev}"

  info "Ensuring latest dump of ${DB_INSTANCE_NAME} is downloaded locally"
  # find the latest dump that exists in google cloud storage
  local LATEST_DUMP_GCS
  LATEST_DUMP_GCS=$(gsutil ls "gs://${BUCKET}/${DB_INSTANCE_NAME}/" | grep .sql.gz | tail -n 1)

  if [[ -z "${LATEST_DUMP_GCS}" ]]; then
    # we clean up the dumps every 30 days, so if there isn't a dump available, create a new one
    info "Did not find recent dump of ${DB_INSTANCE_NAME} in Google Cloud Storage, creating new dump"
    create_database_dump "${DB_INSTANCE_NAME}" "${PROJECT}" "${BUCKET}"
    LATEST_DUMP_GCS=$(gsutil ls "gs://${BUCKET}/${DB_INSTANCE_NAME}/" | grep .sql.gz | tail -n 1)
  fi
  info "Latest dump is ${LATEST_DUMP_GCS}"

  # copy the dump from GCS to local only if the user hasn't already downloaded
  local DUMP_FOLDER
  DUMP_FOLDER="${DIR}/../generated/database-dumps/${DB_INSTANCE_NAME}"
  local LATEST_DUMP_LOCAL
  LATEST_DUMP_LOCAL="${DUMP_FOLDER}/$(basename $LATEST_DUMP_GCS)"
  if [[ -f "${LATEST_DUMP_LOCAL}" ]]; then
    info "Detected ${LATEST_DUMP_LOCAL}, do not need to download again"
  else
    mkdir -p "${DUMP_FOLDER}"
    info "Downloading latest dump of ${DB_INSTANCE_NAME}"
    gsutil cp "${LATEST_DUMP_GCS}" "${DUMP_FOLDER}/"
    info "Successfully downloaded dump to ${LATEST_DUMP_LOCAL}"
  fi

  # return the latest dump
  echo "${LATEST_DUMP_LOCAL}"
  return 0
}


function import_mysql() {
  local DOWNLOADED_MY_SQL_DUMP=${1}

  info "Importing ${DOWNLOADED_MY_SQL_DUMP} into mysql..."
  gunzip -c "${DOWNLOADED_MY_SQL_DUMP}" | docker exec -i public-docker-local-dev_mysql_1 sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'

  return 0
}

function import_postgres() {
  local DOWNLOADED_POSTGRES_DUMP=${1}

  info "Importing ${DOWNLOADED_POSTGRES_DUMP} into postgres..."
  info "Creating 'db' database"
  echo "CREATE DATABASE db;" | docker exec -i public-docker-local-dev_postgres_1 psql
  info "Extracting ${DOWNLOADED_POSTGRES_DUMP} and importing into public-docker-local-dev_postgres_1"
  # we use grep to remove the lines that reference the users that we don't have locally
  # cloudsqladmin and cloudsqlsuperuser users are added by Google's CloudSQL system, and we don't need them here locally
  # db-etl-staging is used by fivetran to copy the database into BigQuery
  gunzip -c "${DOWNLOADED_POSTGRES_DUMP}" | grep -v db-etl-staging | grep -v cloudsqladmin | grep -v cloudsqlsuperuser | docker exec -i public-docker-local-dev_postgres_1 psql -d db

  return 0
}

################## BEGIN Logging taken from https://bash3boilerplate.sh/
LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected

function __b3bp_log () {
  local log_level="${1}"
  shift

  # shellcheck disable=SC2034
  local color_debug="\\x1b[35m"
  # shellcheck disable=SC2034
  local color_info="\\x1b[32m"
  # shellcheck disable=SC2034
  local color_notice="\\x1b[34m"
  # shellcheck disable=SC2034
  local color_warning="\\x1b[33m"
  # shellcheck disable=SC2034
  local color_error="\\x1b[31m"
  # shellcheck disable=SC2034
  local color_critical="\\x1b[1;31m"
  # shellcheck disable=SC2034
  local color_alert="\\x1b[1;37;41m"
  # shellcheck disable=SC2034
  local color_emergency="\\x1b[1;4;5;37;41m"

  local colorvar="color_${log_level}"

  local color="${!colorvar:-${color_error}}"
  local color_reset="\\x1b[0m"

  if [[ "${NO_COLOR:-}" = "true" ]] || { [[ "${TERM:-}" != "xterm"* ]] && [[ "${TERM:-}" != "screen"* ]]; } || [[ ! -t 2 ]]; then
    if [[ "${NO_COLOR:-}" != "false" ]]; then
      # Don't use colors on pipes or non-recognized terminals
      color=""; color_reset=""
    fi
  fi

  # all remaining arguments are to be printed
  local log_line=""

  while IFS=$'\n' read -r log_line; do
    echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}" 1>&2
  done <<< "${@:-}"
}

function emergency () {                                __b3bp_log emergency "${@}"; exit 1; }
function alert ()     { [[ "${LOG_LEVEL:-0}" -ge 1 ]] && __b3bp_log alert "${@}"; true; }
function critical ()  { [[ "${LOG_LEVEL:-0}" -ge 2 ]] && __b3bp_log critical "${@}"; true; }
function error ()     { [[ "${LOG_LEVEL:-0}" -ge 3 ]] && __b3bp_log error "${@}"; true; }
function warning ()   { [[ "${LOG_LEVEL:-0}" -ge 4 ]] && __b3bp_log warning "${@}"; true; }
function notice ()    { [[ "${LOG_LEVEL:-0}" -ge 5 ]] && __b3bp_log notice "${@}"; true; }
function info ()      { [[ "${LOG_LEVEL:-0}" -ge 6 ]] && __b3bp_log info "${@}"; true; }
function debug ()     { [[ "${LOG_LEVEL:-0}" -ge 7 ]] && __b3bp_log debug "${@}"; true; }
############# END Logging

# The useful part of the script

# parse optional flags
# https://www.baeldung.com/linux/use-command-line-arguments-in-bash-script
# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash
while getopts "f" flag
do
    case "${flag}" in
        "f") FORCE_LATEST="true";;
        *) emergency "Invalid argument flag. usage: $0 [-f]"
    esac
done

# allow someone to force new database snapshots to be created
if [[ "${FORCE_LATEST}" == "true" ]]; then
  dump_all_databases
fi

reset_docker_containers
# ensure_latest_downloaded assumes your db is in google cloud projects, so we skip it for this demo project
#DOWNLOADED_MYSQL=$(ensure_latest_downloaded XXX-mysql)
#DOWNLOADED_POSTGRES=$(ensure_latest_downloaded XXX-postgres)
#import_mysql "${DOWNLOADED_MYSQL}"
#import_postgres "${DOWNLOADED_POSTGRES}"

# instead, we just ran a one time export and committed the files into this repository
# docker exec -it public-docker-local-dev_postgres_1 pg_dump -U postgres --format=plain --no-owner --no-acl db | sed -E 's/(DROP|CREATE|COMMENT ON) EXTENSION/-- \1 EXTENSION/g' | gzip -c > database-dumps/postgres.sql.gz
# docker exec -it public-docker-local-dev_mysql_1 mysqldump --all-databases -u root -ppassword --hex-blob --single-transaction --set-gtid-purged=OFF --default-character-set=utf8mb4 | grep -v "Using a password" | gzip -c > database-dumps/mysql.sql.gz
import_mysql "database-dumps/mysql.sql.gz"
import_postgres "database-dumps/postgres.sql.gz"

info "SUCCESS: Database reset is complete!"
