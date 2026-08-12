services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    command: ["start.sh", "immich"]
    volumes:
      - ./upload:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
      - /srv/dev-disk-by-uuid-52E654B8E6549E53/:/usr/src/app/external:ro
    depends_on:
      - redis
      - database
    restart: always
    environment:
      - DB_PASSWORD=postgres
      - DB_USERNAME=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=immich_redis
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(`photos.lan`)"
      - "traefik.http.services.immich.loadbalancer.server.port=2283"
      - "traefik.docker.network=proxy"

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    volumes:
      - ./model-cache:/cache
    restart: always

  redis:
    container_name: immich_redis
    image: redis:6.2-alpine
    restart: always

  database:
    container_name: immich_postgres
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: immich
    volumes:
      - ./postgres:/var/lib/postgresql/data
    restart: always

networks:
  default:
  proxy:
    external: true
    name: proxy