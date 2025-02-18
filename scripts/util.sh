#!/usr/bin/env bash
set -e

UTIL_SOURCED=yes
export UTIL_SOURCED

# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# This sets STAGE to $1 if present and not null, otherwise it sets stage to
# $STAGE from the environment if present, else it defaults to $USER
if [ -z "$1" ]; then 
  echo "STAGE not supplied as command line argument"
  if [ -z "$STAGE" ]; then 
    echo "STAGE not supplied as environment variable STAGE"
    echo "Setting STAGE from environment variable USER: ${USER}"
    STAGE=$USER
  else
    echo "STAGE supplied as environment variable STAGE: ${STAGE}"
  fi
else
  echo "STAGE supplied as command line argument: ${1}"
  STAGE=$1
fi

pushd "${DIR}/.."  > /dev/null
export SOLUTION_ROOT_DIR="${PWD}"
export SOLUTION_DIR="${SOLUTION_ROOT_DIR}/main/solution"
export CONFIG_DIR="${SOLUTION_ROOT_DIR}/main/config"
export INT_TEST_DIR="${SOLUTION_ROOT_DIR}/main/integration-tests"
export E2E_TEST_DIR="${SOLUTION_ROOT_DIR}/main/end-to-end-tests"
# By default, we assume test config file exists. 
# The check for it happens later
export TEST_CONFIG_EXISTS=true
popd > /dev/null

function init_package_manager() {
  PACKAGE_MANAGER=pnpm
  if ! command -v $PACKAGE_MANAGER &> /dev/null; then
    npm install -g pnpm@5.18.9
  fi
  case "$PACKAGE_MANAGER" in
    yarn)
      EXEC="yarn run"
      RUN_SCRIPT="yarn run"
      INSTALL_RECURSIVE="yarn workspaces run install"
      ;;
    npm)
      EXEC="npx"
      RUN_SCRIPT="npm run"
      INSTALL_RECURSIVE=
      ;;
    pnpm)
      EXEC="pnpx"
      RUN_SCRIPT="pnpm run"
      export EXEC RUN_SCRIPT
      INSTALL_RECURSIVE="pnpm recursive install"
      ;;
    *)
      echo "error: Unknown package manager: '${PACKAGE_MANAGER}''" >&2
      exit 1
      ;;
  esac
}

function install_dependencies() {
  init_package_manager

  # Install
  pushd "$SOLUTION_DIR" &> /dev/null
  [[ -n "$INSTALL_RECURSIVE" ]] && $INSTALL_RECURSIVE
  popd
}

# Function to read stage file values
function get_stage_value() {
  key=$1
  set +e
  value="$(cat "$CONFIG_DIR/settings/$STAGE.yml" "$CONFIG_DIR/settings/.defaults.yml" 2> /dev/null | grep '^'$key':' -m 1 | sed 's/ //g' | cut -d':' -f2 | tr -d '\012\015')"
  set -e
  echo $value
}
