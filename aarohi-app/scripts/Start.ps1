$ErrorActionPreference='Stop'
Push-Location "$PSScriptRoot/../web"
try { & npm ci --no-audit --no-fund; if($LASTEXITCODE){throw 'npm install failed'}; & npm run build; if($LASTEXITCODE){throw 'Frontend build failed'} } finally {Pop-Location}
$env:ASPNETCORE_ENVIRONMENT='Development'
& dotnet run --project "$PSScriptRoot/../api/Aarohi.Api.csproj" --urls http://127.0.0.1:5088
