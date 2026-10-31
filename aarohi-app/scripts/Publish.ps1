param([string]$Destination="$PSScriptRoot/../artifacts/publish")
$ErrorActionPreference='Stop'
Push-Location "$PSScriptRoot/../web"
try { & npm ci --no-audit --no-fund; if($LASTEXITCODE){throw 'npm install failed'}; & npm run build; if($LASTEXITCODE){throw 'React build failed'} } finally {Pop-Location}
& dotnet publish "$PSScriptRoot/../api/Aarohi.Api.csproj" -c Release -o $Destination
if($LASTEXITCODE){throw 'Publish failed'}
# Public recipe images retain their database-configured storage keys.
Copy-Item "$PSScriptRoot/../database/assets" "$Destination/assets" -Recurse -Force
Write-Host "Published to $Destination. Set Media__Root to this directory in the deployed environment."
