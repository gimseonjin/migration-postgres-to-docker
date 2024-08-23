#!/bin/bash

# 초기 설정값 (기본값)
DB_NAME="surface_v0_1_1"
DB_USER="surface"
DB_PASSWORD="surface"
DB_HOST="localhost"
DB_PORT="5432"
BACKUP_DIR="./backups"
DOCKER_DB_NAME="surface_v0_1_1"
DOCKER_DB_USER="surface"
DOCKER_DB_PASSWORD="surface"
DOCKER_CONTAINER_NAME="postgres_container"
BACKUP_FILE="$BACKUP_DIR/$DB_NAME.sql"

# 데이터베이스 덤프 함수
function dump_database() {
    read -p "Database Name (local) [default: $DB_NAME]: " input
    DB_NAME=${input:-$DB_NAME}
    read -p "Database User (local) [default: $DB_USER]: " input
    DB_USER=${input:-$DB_USER}
    read -p "Database Host (local) [default: $DB_HOST]: " input
    DB_HOST=${input:-$DB_HOST}
    read -p "Database Port (local) [default: $DB_PORT]: " input
    DB_PORT=${input:-$DB_PORT}
    read -s -p "Database Password (local) [default: hidden]: " input
    DB_PASSWORD=${input:-$DB_PASSWORD}
    echo ""
    read -p "Backup Directory (local) [default: $BACKUP_DIR]: " input
    BACKUP_DIR=${input:-$BACKUP_DIR}
    BACKUP_FILE="$BACKUP_DIR/$DB_NAME.sql"

    if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$BACKUP_DIR" ]]; then
        echo "Missing required values. Please provide all necessary information."
        return
    fi

    echo "Step 1: Starting data dump from on-premises PostgreSQL..."

    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p $BACKUP_DIR
    fi

    PGPASSWORD=$DB_PASSWORD pg_dump -U $DB_USER -h $DB_HOST -p $DB_PORT -F c -b -v -f $BACKUP_FILE $DB_NAME

    if [ $? -eq 0 ]; then
        echo "Step 1: Data dump completed successfully: $BACKUP_FILE"
    else
        echo "Step 1: Data dump failed!" >&2
        return
    fi
}

# 도커로 마이그레이션 함수
function migrate_to_docker() {
    read -p "Docker Database Name [default: $DOCKER_DB_NAME]: " input
    DOCKER_DB_NAME=${input:-$DOCKER_DB_NAME}
    read -p "Docker Database User [default: $DOCKER_DB_USER]: " input
    DOCKER_DB_USER=${input:-$DOCKER_DB_USER}
    read -s -p "Docker Database Password [default: hidden]: " input
    DOCKER_DB_PASSWORD=${input:-$DOCKER_DB_PASSWORD}
    echo ""
    read -p "Docker Container Name [default: $DOCKER_CONTAINER_NAME]: " input
    DOCKER_CONTAINER_NAME=${input:-$DOCKER_CONTAINER_NAME}

    if [[ -z "$BACKUP_FILE" || -z "$DOCKER_DB_NAME" || -z "$DOCKER_DB_USER" || -z "$DOCKER_DB_PASSWORD" || -z "$DOCKER_CONTAINER_NAME" ]]; then
        echo "Missing required values. Please provide all necessary information."
        return
    fi

    echo "Step 1: Copying dump file to Docker container..."

    docker cp $BACKUP_FILE $DOCKER_CONTAINER_NAME:/tmp/

    if [ $? -eq 0 ]; then
        echo "Step 1: Dump file copied successfully."
    else
        echo "Step 1: Failed to copy dump file!" >&2
        return
    fi

    echo "Step 2: Restoring data in Docker container PostgreSQL..."
    docker exec -u postgres $DOCKER_CONTAINER_NAME pg_restore -U $DOCKER_DB_USER -d $DOCKER_DB_NAME -v /tmp/$(basename $BACKUP_FILE)

    if [ $? -eq 0 ]; then
        echo "Step 2: Data restored successfully!"
    else
        echo "Step 2: Data restoration failed!" >&2
    fi
}

# 메인 메뉴
function main_menu() {
    while true; do
        echo ""
        echo "Please choose an option:"
        echo "1. Dump Database"
        echo "2. Migrate to Docker"
        echo "3. Exit"
        read -p "Enter your choice: " choice
        case $choice in
            1)
                dump_database
                ;;
            2)
                migrate_to_docker
                ;;
            3)
                echo "Exiting..."
                break
                ;;
            *)
                echo "Invalid choice! Please select 1, 2, or 3."
                ;;
        esac
    done
}

# 스크립트 실행
main_menu
