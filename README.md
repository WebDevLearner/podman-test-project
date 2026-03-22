# Podman Test Project

Spring Boot API backed by MySQL and RabbitMQ, intended to run with `podman compose`.

## Start Everything On Linux

Run the bootstrap script from the project root:

```bash
bash script.sh
```

If you want to make it executable first:

```bash
chmod +x script.sh
./script.sh
```

The script shows an interactive menu:

```text
Select an option:
1. Start stack
2. Show status
3. Stop stack
```

When you choose `1`, the script:

- Detects `podman compose` or `podman-compose`
- Builds the application and RabbitMQ images
- Starts MySQL, RabbitMQ, and the API
- Waits for MySQL and RabbitMQ health checks
- Probes the API at `http://localhost:8080/api/messages`

## Script Layout

The script has been split for readability:

- `script.sh`: entry point and interactive menu
- `scripts/lib/common.sh`: shared helpers
- `scripts/lib/podman.sh`: Podman and compose setup
- `scripts/lib/stack.sh`: stack lifecycle and health checks

## Services

The compose stack exposes these host ports:

- API: `http://localhost:8080`
- MySQL: `localhost:3307`
- RabbitMQ AMQP: `localhost:5672`
- RabbitMQ Management UI/API: `http://localhost:15672`

## Connection Details

### API

- Base URL: `http://localhost:8080/api/messages`

### MySQL

- JDBC URL: `jdbc:mysql://localhost:3307/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC`
- Native URL: `mysql://root:test@localhost:3307/podman_test`
- Username: `root`
- Password: `test`
- Database: `podman_test`

Inside the compose network, the application connects to:

- `jdbc:mysql://mysql:3306/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC`

### RabbitMQ

- AMQP URL: `amqp://guest:guest@localhost:5672`
- Management URL: `http://guest:guest@localhost:15672`
- Username: `guest`
- Password: `guest`
- Queue: `podman.test.messages`

Inside the compose network, the application connects to:

- `amqp://guest:guest@rabbitmq:5672`

## Verification Commands

### API with curl

PowerShell line continuation uses `` ` ``. If you prefer a single line, remove it.

```powershell
curl http://localhost:8080/api/messages
curl http://localhost:8080/api/messages/1
curl -X POST http://localhost:8080/api/messages `
  -H "Content-Type: application/json" `
  -d "{\"author\":\"Ben\",\"content\":\"hello from curl\"}"
curl -X PUT http://localhost:8080/api/messages/1 `
  -H "Content-Type: application/json" `
  -d "{\"author\":\"Ben\",\"content\":\"updated from curl\"}"
curl -X DELETE http://localhost:8080/api/messages/1
```

### RabbitMQ with curl

```powershell
curl -u guest:guest http://localhost:15672/api/overview
curl -u guest:guest http://localhost:15672/api/queues
curl -u guest:guest http://localhost:15672/api/queues/%2F/podman.test.messages
```

### MySQL with mysql client

```powershell
mysql -h 127.0.0.1 -P 3307 -u root -ptest -D podman_test -e "SELECT NOW();"
mysql -h 127.0.0.1 -P 3307 -u root -ptest -D podman_test -e "SHOW TABLES;"
mysql -h 127.0.0.1 -P 3307 -u root -ptest -D podman_test -e "SELECT * FROM messages;"
```

## Notes

- RabbitMQ is configured with `loopback_users.guest = false`, so the default `guest` account is allowed from outside the container.
- The application persists messages to MySQL and publishes created-message events to RabbitMQ when messaging is enabled.
