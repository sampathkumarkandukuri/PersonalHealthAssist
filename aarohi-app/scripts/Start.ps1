$ErrorActionPreference='Stop'
Push-Location "$PSScriptRoot/../web"
try { & npm ci --no-audit --no-fund; if($LASTEXITCODE){throw 'npm install failed'}; & npm run build; if($LASTEXITCODE){throw 'Frontend build failed'} } finally {Pop-Location}

$preferredPort = 5088
$port = $preferredPort
while ((Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    $port++
}

$apiUrl = "http://127.0.0.1:$port"
$env:ASPNETCORE_ENVIRONMENT='Development'
$env:ASPNETCORE_URLS = $apiUrl
$env:AAROHI_BASE_URL = $apiUrl
Write-Host "Starting Aarohi API on $apiUrl"
& dotnet run --project "$PSScriptRoot/../api/Aarohi.Api.csproj" --urls $apiUrl
