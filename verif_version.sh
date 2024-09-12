#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Récupérer les données de configuration
GITLAB_TOKEN=$(jq -r '.gitlab.token' $SCRIPT_DIR/verif_version.conf)
GITLAB_URL=$(jq -r '.gitlab.url' $SCRIPT_DIR/verif_version.conf)
NTFY_TOKEN=$(jq -r '.ntfy.token' $SCRIPT_DIR/verif_version.conf)
NTFY_URL=$(jq -r '.ntfy.url' $SCRIPT_DIR/verif_version.conf)
SERVER_NAME=$(jq -r '.name' $SCRIPT_DIR/verif_version.conf)

# Définir les URLs
GITLAB_URL="$GITLAB_URL/api/v4/metadata?private_token=$GITLAB_TOKEN"
DOCKER_HUB_URL="https://hub.docker.com/v2/namespaces/gitlab/repositories/gitlab-ce/tags?page=1&page_size=50"

# Récupérer la version actuelle du GitLab installé
GITLAB_VERSION=$(curl -s "$GITLAB_URL" | jq -r '.version')

# Récupérer le digest de la version actuelle
ACTUAL_DIGEST=$(curl -s "$DOCKER_HUB_URL" | jq -r --arg VERSION "$GITLAB_VERSION" '.results[] | select(.name | startswith("\($VERSION)")).digest')

# Récupérer le digest de la dernière version
LATEST_DIGEST=$(curl -s "$DOCKER_HUB_URL" | jq -r --arg VERSION "$GITLAB_VERSION" '.results[] | select(.name == "latest").digest')

# Récupérer le nom de la dernière version
LATEST_VERSION=$(curl -s "$DOCKER_HUB_URL" | jq -r --arg DIGEST "$LATEST_DIGEST" '.results[] | select(.digest == $DIGEST and .name != "rc" and .name != "latest") | .name')

# Récupérer la date de la dernière version
LATEST_DATE=$(curl -s "$DOCKER_HUB_URL" | jq -r --arg DIGEST "$LATEST_DIGEST" '.results[] | select(.digest == $DIGEST and .name != "rc" and .name != "latest").last_updated')
LATEST_DATE_TIMESTAMP=$(date -d "$LATEST_DATE" +%s)

# Comparer les digests
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
if [ "$ACTUAL_DIGEST" = "$LATEST_DIGEST" ]; then
    echo "$TIMESTAMP --> Version $GITLAB_VERSION est a jour." >> $SCRIPT_DIR/maj_docker.log
else
    # Nombre de jours de sécurité avant une mise à jour automatique
    MARGIN=$(jq -r '.margin' $SCRIPT_DIR/verif_version.conf)
    DATE_MARGIN=$(date -d "$MARGIN days ago" +%s)
    if [ $LATEST_DATE_TIMESTAMP -lt $DATE_MARGIN ]; then
        echo "$TIMESTAMP --> Version latest est plus à jour que la version actuelle $GITLAB_VERSION. On met à jour."
        # On notifie que la mise à jour vers telle version va se faire
        curl -H "Title: [$SERVER_NAME] Mise à jour Gitlab" -H "Tags: warning" -d "En cours vers $LATEST_VERSION" $NTFY_URL/maj_gitlab -u :$NTFY_TOKEN
        $SCRIPT_DIR/restart_compose_gitlab.sh
        # On notifie que la mise à jour est terminée avec le nouveau numéro de version
        curl -H "Title: [$SERVER_NAME] Mise à jour Gitlab" -H "Tags: white_check_mark" -d "Version $LATEST_VERSION" $NTFY_URL/maj_gitlab -u :$NTFY_TOKEN
    else
        # On notifie que la version est encore trop récente de X jours
        curl -H "Title: [$SERVER_NAME] Mise à jour Gitlab" -H "Tags: hourglass" -d "Version $LATEST_VERSION date de moins de $MARGIN jour(s)" $NTFY_URL/maj_gitlab -u :$NTFY_TOKEN
    fi
fi
