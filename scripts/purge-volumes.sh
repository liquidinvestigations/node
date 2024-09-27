#!/bin/bash
set -e

cd "$(dirname ${BASH_SOURCE[0]})/.."

if [ -z "$1" ]; then
    echo "No volume path given."
    exit 1
else
    volumes_dir=$1
    echo "Volume path: ${volumes_dir}"
fi

if [ -z "$2" ]; then
    echo "No path for backup location given."
    exit 1
else
    backup_path=$2
    echo "Backup path: ${backup_path}"
fi

if [ -z "$3" ]; then
    echo "No collection name given (for restored collection)."
    exit 1
else
    collection_name=$3
    echo "Collection name: ${collection_name}"
fi


nextcloud_container_id () {
    # ./liquid docker exec throws an error so we connect this way
    container_id=$(docker ps | grep liquid-nextcloud | grep nextcloud28 | awk '{print $1}')

    if [ -z "$container_id" ]; then
        echo "Error: Nextcloud container not found. Make sure the container is running."
        exit 1
    else
        echo $container_id
        return 0
    fi
}

if ! nextcloud_container_id ; then
    echo "Liquid is not running. Exiting the purge script."
    exit 1
fi

./liquid dockerexec liquid:core ./manage.py maintenance --on
./liquid halt --purge-demo-mode
echo "Stopped liquid. Removing volumes."

echo "Removing ${volumes_dir}..."
sudo rm -rf ${volumes_dir}/snoop
sudo rm -rf ${volumes_dir}/nextcloud28
sudo rm -rf ${volumes_dir}/hoover

echo "Removed volumes. Starting liquid again."

./liquid deploy --purge-demo-mode
echo "Liquid deployed successfully."

./liquid restore-collection ${backup_path} ${collection_name}
echo "${collection_name} restored successfully."


# ./liquid docker exec throws an error so we connect this way
container_id=$(nextcloud_container_id)
echo ${container_id}

app_password=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 20)

docker exec -u www-data $container_id /bin/bash -c "export OC_PASS=$app_password && php occ user:resetpassword --password-from-env demo"

./liquid dockerexec hoover:search ./manage.py setupdemo $app_password
./liquid dockerexec liquid:core ./manage.py maintenance --off
