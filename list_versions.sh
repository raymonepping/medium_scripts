#!/bin/bash

# Function to fetch the latest LTS version of a Docker image from Docker Hub
fetch_latest_lts() {
  local image_name="$1"
  local version_pattern="$2"
  curl -s "https://hub.docker.com/v2/repositories/${image_name}/tags/?page_size=100" |
    jq -r '.results[].name' |
    grep -Ev 'latest|stable|dockerhub|rc|beta|alpha|test|fpm|cli|ubi|windows' |
    grep -E "$version_pattern" |
    sort -Vr |
    head -n 1
}

wordpress_version=$(fetch_latest_lts "library/wordpress" '^[0-9]+\.[0-9]+\.[0-9]+$')
mariadb_version=$(fetch_latest_lts "library/mariadb" '^11\.[0-9]+\.[0-9]+$')
node_lts_version=$(fetch_latest_lts "library/node" '^20\.[0-9]+\.[0-9]+$')
nginx_stable_version=$(fetch_latest_lts "library/nginx" '^1\.[0-9]+\.[0-9]+$')
traefik_version=$(fetch_latest_lts "library/traefik" '^[0-9]+\.[0-9]+\.[0-9]+$')

echo "--------------------------------------------------------------"
echo "|                    LTS VERSION LIST                        |"
echo "--------------------------------------------------------------"
printf "| %-40s | %-15s |\n" "Latest WordPress LTS version" "${wordpress_version:-N/A}"
printf "| %-40s | %-15s |\n" "Latest MariaDB LTS version" "${mariadb_version:-N/A}"
printf "| %-40s | %-15s |\n" "Latest Node.js LTS version" "${node_lts_version:-N/A}"
printf "| %-40s | %-15s |\n" "Latest Nginx LTS version" "${nginx_stable_version:-N/A}"
printf "| %-40s | %-15s |\n" "Latest Traefik version" "${traefik_version:-N/A}"
echo "--------------------------------------------------------------"
