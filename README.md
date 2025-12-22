# Docker buildx

Démonstration de build multi-plateformes / archi : amd64 (x86) et arm64 (M1/M2, Rasberry, AWS Graviton), pour ne produire qu'une seule référence (**fastapi-multiarch**) d'image (OCI) contenant 2 manifests : 1 par type d'architecture.

## Prérequis 

**Buildx**

```
$ docker buildx version
github.com/docker/buildx v0.30.1-desktop.1 792b8327a475a5d8c9d5f4ea6ce866e7da39ae8b
```

** Création d'un builder **

```bash
docker buildx rm multiarch-builder
docker buildx create --name multiarch-builder --driver docker-container --config ./buildkitd.toml --use
```

Le **buildkitd.toml** permet au builder d'utiliser http (sans certificats TLS) sur le FQDN local et port 5000 du registry : **host.docker.internal**

**Registry local**

Pour plus de facilité, un registry local doit exister, pour le --push vers celui-ci lors du build de l'image multi-architectures

```
$ docker compose -f registry2.yml up -d
```

NB : il est possible de directement mettre dans le **daemon.json** des règles d'exception pour indiquer les serveurs registry en accès non sécurisé :

```json
{
  "insecure-registries": ["host.docker.internal:5000", "localhost:5000"]
}
```

ou de créer un TLS auto-signé.

## Build multi-archi

Crée une image fastapi sur pour 2 architecteurs.

```bash
$ docker buildx build --platform linux/amd64,linux/arm64 \
  -t host.docker.internal:5000/fastapi-multiarch:latest \
  -f Dockerfile.fastapi \
  --push \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .
```

Si on force un pull sur une architecture non supportée par la machine qui crée le build, une erreur d'exécution aura lieu - exemple : ARM alors que seul l'AMD fonctionne sur mon poste 

```bash
$ docker pull --platform linux/arm64 host.docker.internal:5000/fastapi-multiarch:latest
```

cela ne fonctionne pas sur une archi AMD64 (x86)

```bash
$ docker run --rm -p 80:80 fastapi-multiarch:amd64
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64/v3) and no specific platform was requested
exec /usr/local/bin/uvicorn: exec format error
```

## Webapp

Après un build, pull de l'image précédemment construite

```bash
$ docker pull host.docker.internal:5000/fastapi-multiarch:latest
```

on pourrait forcer :

```bash
$ docker pull --platform linux/amd64 host.docker.internal:5000/fastapi-multiarch:latest
```

```bash
$ docker run --rm -p 80:80 host.docker.internal:5000/fastapi-multiarch
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:80 (Press CTRL+C to quit)
```

en allant sur http://localhost/arch :
```json
{
architecture: "x86_64"
}
```

## Script de démo 

```bash
$ ./multi-arch.sh
```
