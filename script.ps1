Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ApiBaseUrl = "http://localhost:8080/api/messages"
$PodmanMachineName = "podman-machine-default"
$PodmanConnectionName = "$PodmanMachineName-root"

$MysqlContainer = "podman-test-mysql"
$RabbitMqContainer = "podman-test-rabbitmq"
$AppContainer = "podman-test-api-compose"
$NetworkName = "podman-test-network"
$RabbitMqImage = "localhost/podman-test-rabbitmq:latest"
$AppImage = "localhost/podman-test-app:latest"
$TargetDir = Join-Path $ScriptDir "target"

function Get-SupportedJavaHome {
    $candidates = @()

    if ($env:JAVA_HOME) {
        $candidates += $env:JAVA_HOME
    }

    $candidates += @(
        "C:\Program Files\Java\jdk-23",
        "C:\Program Files\Java\jdk-22",
        "C:\Program Files\Java\jdk-21"
    )

    foreach ($candidate in $candidates) {
        $javaExe = Join-Path $candidate "bin\java.exe"
        if (-not (Test-Path $javaExe)) {
            continue
        }

        $versionOutput = cmd.exe /d /c """$javaExe"" -version 2>&1"
        if ($LASTEXITCODE -ne 0) {
            continue
        }

        $versionText = ($versionOutput | Out-String)
        $versionMatch = [regex]::Match($versionText, 'version "(\d+)(?:\.\d+)?')
        if ($versionMatch.Success) {
            $majorVersion = [int]$versionMatch.Groups[1].Value
            if ($majorVersion -ge 21 -and $majorVersion -lt 24) {
                return $candidate
            }
        }
    }

    return $null
}

function Set-SupportedJavaHome {
    $javaHome = Get-SupportedJavaHome
    if (-not $javaHome) {
        Fail "Spring Boot 3.4.9 requires a host JDK in the 21-23 range to build this project."
    }

    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaHome\bin;$env:Path"
    Write-Log "Using host Java from $javaHome"
}

function Write-Log {
    param([string]$Message)
    Write-Host "[podman-test] $Message"
}

function Fail {
    param([string]$Message)
    throw $Message
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Required command not found: $Name"
    }
}

function Invoke-Podman {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    & podman --connection $PodmanConnectionName @Args
    if ($LASTEXITCODE -ne 0) {
        Fail "podman command failed: podman --connection $PodmanConnectionName $($Args -join ' ')"
    }
}

function Test-PodmanMachineExists {
    & podman machine inspect $PodmanMachineName *> $null
    return $LASTEXITCODE -eq 0
}

function Ensure-PodmanMachineRunning {
    Write-Log "Checking Podman machine"

    if (-not (Test-PodmanMachineExists)) {
        Write-Log "Initializing Podman machine '$PodmanMachineName'"
        & podman machine init $PodmanMachineName
        if ($LASTEXITCODE -ne 0) {
            Fail "Unable to initialize Podman machine '$PodmanMachineName'"
        }
    }

    $machineInfoJson = & podman machine inspect $PodmanMachineName
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to inspect Podman machine '$PodmanMachineName'"
    }

    $machineInfo = $machineInfoJson | ConvertFrom-Json
    if ($machineInfo[0].State -ne "running") {
        Write-Log "Starting Podman machine '$PodmanMachineName'"
        & podman machine start $PodmanMachineName
        if ($LASTEXITCODE -ne 0) {
            Fail "Unable to start Podman machine '$PodmanMachineName'"
        }
    }

    & podman system connection list *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to read Podman system connections"
    }

    & podman --connection $PodmanConnectionName info *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail "Podman connection '$PodmanConnectionName' is not available. Run 'podman system connection list' and fix the Podman machine connections."
    }
}

function Wait-ForApi {
    param(
        [int]$TimeoutSeconds = 180
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest -Uri $ApiBaseUrl -UseBasicParsing | Out-Null
            Write-Log "API is responding at $ApiBaseUrl"
            return
        }
        catch {
            Start-Sleep -Seconds 2
        }
    }

    & podman --connection $PodmanConnectionName logs $AppContainer
    Fail "Timed out waiting for API to respond at $ApiBaseUrl"
}

function Get-ContainerState {
    param([string]$ContainerName)

    $state = & podman --connection $PodmanConnectionName inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" $ContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($state | Out-String).Trim()
}

function Wait-ForContainerState {
    param(
        [string]$ContainerName,
        [string]$ExpectedState,
        [int]$TimeoutSeconds = 180
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $state = Get-ContainerState -ContainerName $ContainerName

        if ($state -eq $ExpectedState) {
            Write-Log "$ContainerName is $ExpectedState"
            return
        }

        if ($state -in @("unhealthy", "exited", "stopped")) {
            & podman --connection $PodmanConnectionName logs $ContainerName
            Fail "$ContainerName entered unexpected state: $state"
        }

        Start-Sleep -Seconds 2
    }

    & podman --connection $PodmanConnectionName logs $ContainerName
    Fail "Timed out waiting for $ContainerName to become $ExpectedState"
}

function Build-Images {
    Write-Log "Building RabbitMQ image with podman"
    Invoke-Podman build -t $RabbitMqImage -f (Join-Path $ScriptDir "rabbitmq\Containerfile") (Join-Path $ScriptDir "rabbitmq")

    Set-SupportedJavaHome
    Write-Log "Building application JAR on the host"
    Get-ChildItem -Path $TargetDir -Filter *.jar -ErrorAction SilentlyContinue | Remove-Item -Force
    & (Join-Path $ScriptDir "mvnw.cmd") clean package -DskipTests
    if ($LASTEXITCODE -ne 0) {
        Fail "Host Maven build failed"
    }

    if (-not (Get-ChildItem -Path $TargetDir -Filter *.jar -ErrorAction SilentlyContinue)) {
        Fail "Host build completed without producing target\*.jar"
    }

    Write-Log "Building application image with podman"
    Invoke-Podman build -t $AppImage -f (Join-Path $ScriptDir "Containerfile") $ScriptDir
}

function Remove-ContainerIfPresent {
    param([string]$ContainerName)

    & podman --connection $PodmanConnectionName container exists $ContainerName *> $null
    if ($LASTEXITCODE -eq 0) {
        Invoke-Podman rm -f $ContainerName
    }
}

function Ensure-Network {
    & podman --connection $PodmanConnectionName network exists $NetworkName *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Podman network create $NetworkName
    }
}

function Run-Mysql {
    Remove-ContainerIfPresent -ContainerName $MysqlContainer
    $args = @(
        "run", "-d",
        "--name", $MysqlContainer,
        "--network", $NetworkName,
        "--network-alias", "mysql",
        "-e", "MYSQL_ROOT_PASSWORD=test",
        "-e", "MYSQL_DATABASE=podman_test",
        "-p", "3307:3306",
        "--health-cmd", "mysqladmin ping -h 127.0.0.1 -uroot -ptest",
        "--health-interval", "10s",
        "--health-timeout", "5s",
        "--health-retries", "10",
        "docker.io/library/mysql:8.0"
    )
    Invoke-Podman @args
}

function Run-RabbitMq {
    Remove-ContainerIfPresent -ContainerName $RabbitMqContainer
    $args = @(
        "run", "-d",
        "--name", $RabbitMqContainer,
        "--network", $NetworkName,
        "--network-alias", "rabbitmq",
        "-p", "5672:5672",
        "-p", "15672:15672",
        "--health-cmd", "rabbitmq-diagnostics -q ping",
        "--health-interval", "10s",
        "--health-timeout", "5s",
        "--health-retries", "10",
        $RabbitMqImage
    )
    Invoke-Podman @args
}

function Run-App {
    Remove-ContainerIfPresent -ContainerName $AppContainer
    $args = @(
        "run", "-d",
        "--name", $AppContainer,
        "--network", $NetworkName,
        "-e", "DB_URL=jdbc:mysql://mysql:3306/podman_test?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC",
        "-e", "DB_USERNAME=root",
        "-e", "DB_PASSWORD=test",
        "-e", "RABBITMQ_HOST=rabbitmq",
        "-e", "RABBITMQ_PORT=5672",
        "-e", "RABBITMQ_USERNAME=guest",
        "-e", "RABBITMQ_PASSWORD=guest",
        "-e", "MESSAGING_ENABLED=true",
        "-e", "MESSAGING_QUEUE=podman.test.messages",
        "-p", "8080:8080",
        $AppImage
    )
    Invoke-Podman @args
}

function Show-Status {
    Write-Log "Containers"
    Invoke-Podman ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
    Write-Host ""
    Write-Log "Networks"
    Invoke-Podman network ls --format "table {{.Name}}`t{{.Driver}}"
}

function Start-Stack {
    Ensure-PodmanMachineRunning
    Build-Images
    Ensure-Network
    Write-Log "Starting MySQL, RabbitMQ, and the Spring Boot API"
    Run-Mysql
    Run-RabbitMq
    Wait-ForContainerState -ContainerName $MysqlContainer -ExpectedState "healthy"
    Wait-ForContainerState -ContainerName $RabbitMqContainer -ExpectedState "healthy"
    Run-App
    Wait-ForContainerState -ContainerName $AppContainer -ExpectedState "running"
    Wait-ForApi
    Show-Status
}

function Stop-Stack {
    Ensure-PodmanMachineRunning
    Write-Log "Stopping containers"
    Remove-ContainerIfPresent -ContainerName $AppContainer
    Remove-ContainerIfPresent -ContainerName $RabbitMqContainer
    Remove-ContainerIfPresent -ContainerName $MysqlContainer

    & podman --connection $PodmanConnectionName network exists $NetworkName *> $null
    if ($LASTEXITCODE -eq 0) {
        Invoke-Podman network rm $NetworkName
    }
}

function Show-Menu {
    Write-Host "Select an option:"
    Write-Host "1. Start stack"
    Write-Host "2. Show status"
    Write-Host "3. Stop stack"
}

Require-Command podman

Show-Menu
$choice = Read-Host "Enter choice [1-3]"

switch ($choice) {
    "1" { Start-Stack }
    "2" {
        Ensure-PodmanMachineRunning
        Show-Status
    }
    "3" { Stop-Stack }
    default { Fail "Unknown selection: $choice. Choose 1, 2, or 3." }
}
