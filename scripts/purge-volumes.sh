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

if [ ! -f ./.demo_mode ]; then
    echo "Error: Demo mode not active. Exiting"
    exit 1
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

./liquid halt
echo "Stopped liquid. Removing volumes."

echo "Removing ${volumes_dir}..."
sudo rm -rf ${volumes_dir}

echo "Removed volumes. Starting liquid again."

./liquid deploy
echo "Liquid deployed successfully."


# ./liquid docker exec throws an error so we connect this way
container_id=$(nextcloud_container_id)
echo ${container_id}

app_password=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 20)

docker exec -u www-data $container_id /bin/bash -c "export OC_PASS=$app_password && php occ user:resetpassword --password-from-env demo"

./liquid dockerexec hoover:search ./manage.py setupdemo $app_password
