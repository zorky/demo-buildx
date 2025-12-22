#!/bin/bash
# Démonstration complète du build et pull multi-architecture avec Docker
# Usage: ./demo-multiarch.sh

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function write_section() {
    echo -e "\n${CYAN}================================================================================"
    echo -e " ${GREEN}$1${CYAN}"
    echo -e "================================================================================${NC}"
}

function write_info() {
    echo -e "  ${YELLOW}ℹ️  $1${NC}"
}

function write_success() {
    echo -e "  ${GREEN}✅ $1${NC}"
}

function write_error() {
    echo -e "  ${RED}❌ $1${NC}"
}

function write_command() {
    echo -e "  ${MAGENTA}\$ $1${NC}"
}

# Variables
REGISTRY_URL="host.docker.internal:5000"
IMAGE_NAME="fastapi-multiarch"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${CYAN}"
cat << "EOF"

  ____             _             __  __       _ _   _        _             _     
 |  _ \  ___   ___| | _____ _ __|  \/  |_   _| | |_(_)      / \   _ __ ___| |__  
 | | | |/ _ \ / __| |/ / _ \ '__| |\/| | | | | | __| |____ / _ \ | '__/ __| '_ \ 
 | |_| | (_) | (__|   <  __/ |  | |  | | |_| | | |_| |___/ ___ \| | | (__| | | |
 |____/ \___/ \___|_|\_\___|_|  |_|  |_|\__,_|_|\__|_|  /_/   \_\_|  \___|_| |_|
                                                                                   
                    Démonstration Build Multi-Plateforme

EOF
echo -e "${NC}"

# 1. Architecture actuelle
write_section "1. Détection de l'architecture"
write_command "docker version --format '{{.Server.Arch}}'"
CURRENT_ARCH=$(docker version --format '{{.Server.Arch}}')
write_success "Architecture de cette machine: $CURRENT_ARCH"

if [ "$CURRENT_ARCH" = "amd64" ]; then
    OTHER_ARCH="arm64"
else
    OTHER_ARCH="amd64"
fi
write_info "L'autre architecture disponible sera: $OTHER_ARCH"

# 2. Nettoyage
write_section "2. Nettoyage des images locales"
write_command "docker rmi $FULL_IMAGE_NAME --force"
docker rmi "$FULL_IMAGE_NAME" --force 2>/dev/null
write_success "Images locales nettoyées"

# 3. Build multi-plateforme
write_section "3. Build multi-plateforme (AMD64 + ARM64)"
write_command "docker buildx build --platform linux/amd64,linux/arm64 -t $FULL_IMAGE_NAME --push ."
write_info "Construction en cours... Cela peut prendre quelques minutes"

docker buildx build --platform linux/amd64,linux/arm64 \
    -t "$FULL_IMAGE_NAME" \
    -f Dockerfile.fastapi \
    --push \
    . >/dev/null 2>&1

if [ $? -eq 0 ]; then
    write_success "Build réussi et pushé vers le registry local"
else
    write_error "Erreur lors du build"
    exit 1
fi

# 4. Inspection du manifest
write_section "4. Inspection du manifest list"
write_command "docker buildx imagetools inspect $FULL_IMAGE_NAME"
docker buildx imagetools inspect "$FULL_IMAGE_NAME"

# 5. Pull automatique
write_section "5. Pull automatique (sélection automatique de $CURRENT_ARCH)"
write_command "docker pull $FULL_IMAGE_NAME"
write_info "Docker va automatiquement sélectionner l'image $CURRENT_ARCH"
docker pull "$FULL_IMAGE_NAME"

# 6. Vérification
write_section "6. Vérification de l'architecture téléchargée"
write_command "docker image inspect $FULL_IMAGE_NAME --format '{{.Architecture}}'"
PULLED_ARCH=$(docker image inspect "$FULL_IMAGE_NAME" --format '{{.Architecture}}')
write_success "Architecture téléchargée: $PULLED_ARCH"

if [ "$PULLED_ARCH" = "$CURRENT_ARCH" ]; then
    write_success "✅ CORRECT: Docker a automatiquement sélectionné l'architecture native!"
else
    echo -e "  ${YELLOW}⚠️  ATTENTION: Architecture différente de celle attendue${NC}"
fi

# 7. Comparaison des digests
write_section "7. Comparaison des images par architecture"

write_command "docker image inspect --platform linux/amd64 $FULL_IMAGE_NAME --format '{{.Id}}'"
docker pull --platform linux/amd64 "$FULL_IMAGE_NAME" >/dev/null 2>&1
DIGEST_AMD64=$(docker image inspect --platform linux/amd64 "$FULL_IMAGE_NAME" --format '{{.Id}}')
echo -e "  AMD64 Digest: ${CYAN}$DIGEST_AMD64${NC}"

write_command "docker image inspect --platform linux/arm64 $FULL_IMAGE_NAME --format '{{.Id}}'"
docker pull --platform linux/arm64 "$FULL_IMAGE_NAME" >/dev/null 2>&1
DIGEST_ARM64=$(docker image inspect --platform linux/arm64 "$FULL_IMAGE_NAME" --format '{{.Id}}')
echo -e "  ARM64 Digest: ${CYAN}$DIGEST_ARM64${NC}"

if [ "$DIGEST_AMD64" != "$DIGEST_ARM64" ]; then
    write_success "✅ Les deux images ont des digests différents (images distinctes)"
else
    echo -e "  ${YELLOW}⚠️  Les digests sont identiques (inattendu)${NC}"
fi

# 8. Taille des images
write_section "8. Taille des images par architecture"
write_command "docker images $FULL_IMAGE_NAME"
docker images "$FULL_IMAGE_NAME"

# 9. Test API du registry
write_section "9. Inspection via l'API du registry"
write_command "curl http://localhost:5000/v2/$IMAGE_NAME/tags/list"

# Test si curl est disponible
if command -v curl >/dev/null 2>&1; then
    TAGS_RESPONSE=$(curl -s "http://localhost:5000/v2/$IMAGE_NAME/tags/list" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$TAGS_RESPONSE" ]; then
        TAGS=$(echo "$TAGS_RESPONSE" | grep -o '"tags":\[.*\]' | sed 's/"tags":\[//;s/\]//')
        write_info "Tags disponibles: $TAGS"
        
        MANIFEST_RESPONSE=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.index.v1+json" \
            "http://localhost:5000/v2/$IMAGE_NAME/manifests/$IMAGE_TAG" 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$MANIFEST_RESPONSE" ]; then
            MANIFEST_COUNT=$(echo "$MANIFEST_RESPONSE" | grep -o '"platform"' | wc -l)
            write_info "Nombre de manifests (architectures): $MANIFEST_COUNT"
            
            # Extraction simplifiée des plateformes
            echo "$MANIFEST_RESPONSE" | grep -o '"os":"[^"]*","architecture":"[^"]*"' | while read -r line; do
                OS=$(echo "$line" | sed 's/.*"os":"\([^"]*\)".*/\1/')
                ARCH=$(echo "$line" | sed 's/.*"architecture":"\([^"]*\)".*/\1/')
                echo -e "    ${NC}• $OS/$ARCH"
            done
        fi
    else
        echo -e "  ${YELLOW}⚠️  Impossible d'accéder au registry via l'API${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  curl n'est pas disponible${NC}"
fi

# 10. Résumé
write_section "10. Résumé de la démonstration"
echo -e "${GREEN}"
cat << EOF
  
  📦 Image multi-plateforme créée: $FULL_IMAGE_NAME
  
  🎯 Points démontrés:
     1. Une seule commande build pour plusieurs architectures
     2. Un manifest list contient les références aux images spécifiques
     3. Docker sélectionne automatiquement la bonne architecture au pull
     4. Les images AMD64 et ARM64 sont distinctes (digests différents)
     5. Possibilité de forcer une architecture avec --platform
  
  🚀 L'image peut maintenant être déployée sur:
     • Serveurs x86_64 (Intel/AMD)
     • Serveurs ARM64 (AWS Graviton, Raspberry Pi, etc.)
     • Mac Apple Silicon (M1/M2/M3)
  
  ✨ Le tout avec une seule référence d'image!
  
EOF
echo -e "${NC}"

echo -e "${CYAN}Démo terminée!${NC}"