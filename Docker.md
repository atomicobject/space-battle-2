# Running the Clients with Docker Compose

__Note__: In base directory ->
```
docker compose up
```

Run Server (see above)

# Running the Server with Docker

```
docker buildx build -f server/Dockerfile server/ -t server
```

```
docker run --network=host server
```
__Note__: This assumes you have two clients running on localhost using post 9091 and 9092.

# Run Single Player and Server with Docker compose

```
docker compose --profile single-player up server
```

# Run Two Players and Server with Docker compose

```
docker compose --profile battle up battle-server
```
