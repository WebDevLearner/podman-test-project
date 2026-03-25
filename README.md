# Podman Test Project

Spring Boot API backed by MySQL and RabbitMQ, intended to run with Podman.

## Start Everything From Bash On Linux

Run the bootstrap script from the project root:
##Fix the permissions
cd /home/u.7905589/Documents/<your poman test project location>
chmod +x mvnw
chmod +x scripts/*
chmod +x scripts/lib/*

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

- Builds the Spring Boot JAR on the host with a supported JDK
- Builds the application and RabbitMQ images
- Starts MySQL, RabbitMQ, and the API
- Waits for MySQL and RabbitMQ health checks
- Probes the API at `http://localhost:8080/api/messages`

## Start Everything On Windows PowerShell

Run the PowerShell bootstrap script from the project root:

```powershell
.\script.ps1
```

The script shows the same interactive menu:

```text
Select an option:
1. Start stack
2. Show status
3. Stop stack
```

When you choose `1`, the script:

- Verifies `podman` is installed
- Initializes the default Podman machine if needed
- Starts the Podman machine if it is stopped
- Selects a supported host JDK, preferring `21` and allowing `22` or `23`
- Builds the Spring Boot JAR on the host
- Builds the application and RabbitMQ images
- Starts MySQL, RabbitMQ, and the API with Podman
- Waits for MySQL and RabbitMQ health checks
- Waits for the API at `http://localhost:8080/api/messages`

## Start Everything From Command Prompt On Windows

Run the PowerShell bootstrap script from the project root through `powershell.exe`:

```cmd
powershell.exe -ExecutionPolicy Bypass -File ".\script.ps1"
```

The script shows the same interactive menu:

```text
Select an option:
1. Start stack
2. Show status
3. Stop stack
```

When you choose `1`, the script:

- Verifies `podman` is installed
- Initializes the default Podman machine if needed
- Starts the Podman machine if it is stopped
- Selects a supported host JDK, preferring `21` and allowing `22` or `23`
- Builds the Spring Boot JAR on the host
- Builds the application and RabbitMQ images
- Starts MySQL, RabbitMQ, and the API with Podman
- Waits for MySQL and RabbitMQ health checks
- Waits for the API at `http://localhost:8080/api/messages`

## Script Layout

The script has been split for readability:

- `script.sh`: entry point and interactive menu
- `script.ps1`: Windows PowerShell entry point and interactive menu
- `scripts/lib/common.sh`: shared helpers
- `scripts/lib/podman.sh`: Podman setup
- `scripts/lib/stack.sh`: stack lifecycle and health checks

## Services

## Build Requirements

- Spring Boot `3.4.9`
- Host JDK `21` preferred for local Maven builds; `22` and `23` also supported
- Container runtime image remains Java `21`

The stack exposes these host ports:

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

Inside the Podman network, the application connects to:

- `jdbc:mysql://mysql:3306/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC`

### RabbitMQ

- AMQP URL: `amqp://guest:guest@localhost:5672`
- Management URL: `http://guest:guest@localhost:15672`
- Username: `guest`
- Password: `guest`
- Queue: `podman.test.messages`

Inside the Podman network, the application connects to:

- `amqp://guest:guest@rabbitmq:5672`

## Verification Commands

Use the section that matches both your shell and your Podman setup:

- Linux Bash: use the plain `bash` and `podman` examples
- Windows PowerShell or `cmd` with `script.ps1`: use the Windows Podman machine variants when shown
- Git Bash on Windows: use the Bash variants marked for Windows Podman machine when shown

### API with curl

#### Bash On Linux

```bash
curl http://localhost:8080/api/messages
curl http://localhost:8080/api/messages/1
curl -X POST http://localhost:8080/api/messages \
  -H "Content-Type: application/json" \
  -d '{"author":"Ben","content":"hello from curl"}'
curl -X PUT http://localhost:8080/api/messages/1 \
  -H "Content-Type: application/json" \
  -d '{"author":"Ben","content":"updated from curl"}'
curl -X DELETE http://localhost:8080/api/messages/1
```

#### PowerShell

Use `curl.exe` instead of `curl` so PowerShell does not route the command to `Invoke-WebRequest`.

```powershell
curl.exe http://localhost:8080/api/messages
curl.exe http://localhost:8080/api/messages/1
curl.exe -X POST http://localhost:8080/api/messages `
  -H "Content-Type: application/json" `
  -d '{"author":"Ben","content":"hello from curl"}'
curl.exe -X PUT http://localhost:8080/api/messages/1 `
  -H "Content-Type: application/json" `
  -d '{"author":"Ben","content":"updated from curl"}'
curl.exe -X DELETE http://localhost:8080/api/messages/1
```

#### Command Prompt

Use `curl.exe` and keep each command on one line.

```cmd
curl.exe http://localhost:8080/api/messages
curl.exe http://localhost:8080/api/messages/1
curl.exe -X POST http://localhost:8080/api/messages -H "Content-Type: application/json" -d "{\"author\":\"Ben\",\"content\":\"hello from curl\"}"
curl.exe -X PUT http://localhost:8080/api/messages/1 -H "Content-Type: application/json" -d "{\"author\":\"Ben\",\"content\":\"updated from curl\"}"
curl.exe -X DELETE http://localhost:8080/api/messages/1
```

### RabbitMQ with curl

#### Bash On Linux

```bash
curl -u guest:guest http://localhost:15672/api/overview
curl -u guest:guest http://localhost:15672/api/queues
curl -u guest:guest http://localhost:15672/api/queues/%2F/podman.test.messages
```

#### PowerShell

```powershell
curl -u guest:guest http://localhost:15672/api/overview
curl -u guest:guest http://localhost:15672/api/queues
curl -u guest:guest http://localhost:15672/api/queues/%2F/podman.test.messages
```

#### Command Prompt

```cmd
curl.exe -u guest:guest http://localhost:15672/api/overview
curl.exe -u guest:guest http://localhost:15672/api/queues
curl.exe -u guest:guest http://localhost:15672/api/queues/%2F/podman.test.messages
```

### MySQL with podman exec

#### Bash On Linux

```bash
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

#### Bash On Windows With Podman Machine

If you are using Git Bash or another Bash terminal on Windows with `script.ps1`, use the machine connection explicitly:

```bash
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

#### PowerShell

```powershell
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

#### PowerShell With Windows Podman Machine

If you are using the Windows PowerShell script with a Podman machine, use the machine connection explicitly:

```powershell
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

#### Command Prompt

```cmd
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

#### Command Prompt With Windows Podman Machine

```cmd
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT NOW();"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SHOW TABLES;"
podman --connection podman-machine-default-root exec -it podman-test-mysql mysql -uroot -ptest -D podman_test -e "SELECT * FROM messages;"
```

## Notes

- RabbitMQ is configured with `loopback_users.guest = false`, so the default `guest` account is allowed from outside the container.
- The application persists messages to MySQL and publishes created-message events to RabbitMQ when messaging is enabled.


