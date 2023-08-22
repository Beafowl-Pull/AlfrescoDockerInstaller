check_if_docker_is_installed() {
    if ! command -v docker &> /dev/null
    then
        echo "Docker could not be found. Please install docker and try again."
        exit
    fi
}

check_if_docker_is_running() {
    if ! docker info &> /dev/null
    then
        echo "Docker is not running. Please start docker and try again."
        exit
    fi
}

write_start_sh() {
    echo '#!/usr/bin/env bash

    show_help() {
      echo "Usage: ./start.sh"
      echo ""
      echo "-d or --down delete all container"
      echo "-wp or --windows-path convert to Windows path"
      echo "-wt or --wait-time wait for backend in s. <= 0 no wait at all. Default 500s"
      echo "-h or --help"
    }

    set_windows_path(){
      export COMPOSE_CONVERT_WINDOWS_PATHS=1
    }

    down(){
      sudo docker compose down
      exit 0
    }

    set_wait_time(){
      WAIT_TIME=$1
    }

    # Defaults
    WAIT_TIME=500
    SERVER_NAME="localhost"
    SERVER_PORT="80"

    while [[ $1 == -* ]]; do
      case "$1" in
        -h|--help|-\?) show_help; exit 0;;
        -wp|--windows-path)  set_windows_path; shift;;
        -d|--down)  down; shift;;
        -wt|--wait-time)  set_wait_time $2; shift 2;;
        -*) echo "invalid option: $1" 1>&2; show_help; exit 1;;
      esac
    done

    echo "Start docker compose"
    sudo docker compose up -d --build

    echo "Checking wait-on module availability"
    npm list -g wait-on || npm install -g wait-on

    if [[ $WAIT_TIME -gt 0 ]]; then
      echo "Waiting for alfresco to boot ..."
      WAIT_TIME=$(( ${WAIT_TIME} * 1000 ))
      npx -y wait-on "http://${SERVER_NAME}:${SERVER_PORT}/alfresco/" -t "${WAIT_TIME}" -i 10000 -v
      if [ $? == 1 ]; then
        echo "Waiting failed -> exit 1"
        exit 1
      fi
    fi
    ' >> start.sh
}

install_requirements() {
    sudo yum install -y npm
}

install_files_alfresco() {
    echo "Check if docker is installed..."
    check_if_docker_is_installed
    echo "Check if docker is running..."
    check_if_docker_is_running
    echo "Installing requirements..."
    install_requirements
    echo "Installing Alfresco files..."
    mkdir alfresco
    cd alfresco
    sudo docker run -it -v $(pwd):/generated angelborroy/alfresco-installer
    sudo ./create_volumes.sh
    echo "Writing start.sh..."
    write_start_sh
    sudo ./start.sh
}

install_files_alfresco
