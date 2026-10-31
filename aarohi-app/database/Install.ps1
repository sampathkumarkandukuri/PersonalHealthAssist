[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Server,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,119}$')][string]$Database,
    [switch]$CreateDatabase,
    [switch]$IncludeDemo,
    [switch]$RunTests,
    [string]$SqlUser,
    [switch]$Entra
)
$ErrorActionPreference='Stop'
if ($SqlUser -and $Entra) { throw 'Choose SQL login or Entra authentication, not both.' }
if ($RunTests -and -not $IncludeDemo) { throw 'Use -IncludeDemo with -RunTests on a disposable test database.' }
if ($SqlUser -and -not $env:SQLCMDPASSWORD) { throw 'Set SQLCMDPASSWORD outside this script for SQL authentication. Do not put passwords in scripts.' }
$sqlcmd=(Get-Command sqlcmd -ErrorAction Stop).Source
$connectionArgs=@('-S',$Server,'-b','-f','65001','-r','1')
if ($SqlUser) { $connectionArgs+=@('-U',$SqlUser) }
elseif ($Entra) { $connectionArgs+='-G' }
else { $connectionArgs+='-E' }
function Invoke-AarohiSql([string[]]$Arguments) {
    & $sqlcmd @connectionArgs @Arguments
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed with exit code $LASTEXITCODE. Deployment stopped." }
}
if ($CreateDatabase) {
    Invoke-AarohiSql @('-d','master','-Q',"IF DB_ID(N'$Database') IS NULL EXEC(N'CREATE DATABASE [$Database]');")
}
Invoke-AarohiSql @('-d',$Database,'-Q',"IF TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))<15 AND SERVERPROPERTY('EngineEdition')<>5 THROW 52000,'SQL Server 2019+ or Azure SQL Database is required.',1;")
$scripts=@('001_schema.sql','002_reference_data.sql')
if ($IncludeDemo) { $scripts+='003_demo_data.sql' }
$scripts+=@('004_views_security.sql','005_integrity.sql')
$scripts+=@('008_latest_design_schema.sql','009_latest_design_reference.sql')
if ($IncludeDemo) { $scripts+='010_latest_design_demo.sql' }
$scripts+='011_latest_design_views.sql'
if ($RunTests) { $scripts+=@('006_tests.sql','012_latest_design_tests.sql') }
foreach ($script in $scripts) {
    Write-Host "Applying $script to $Server / $Database"
    Invoke-AarohiSql @('-d',$Database,'-i',(Join-Path $PSScriptRoot $script))
}
Write-Host 'Completed. No API, authentication provider, scheduler or retailer connection was enabled.'
