param([string]$Server='(localdb)\AarohiSchemaTest',[string]$Database='AarohiApplication',[switch]$IncludeDemo)
$ErrorActionPreference='Stop'
& "$PSScriptRoot/../database/Install.ps1" -Server $Server -Database $Database -CreateDatabase -IncludeDemo:$IncludeDemo
foreach($file in @('014_application.sql','015_invitations.sql')) {
 & sqlcmd -S $Server -d $Database -E -b -f 65001 -i "$PSScriptRoot/../database/$file"
 if($LASTEXITCODE -ne 0){throw "Migration failed: $file"}
}
Write-Host 'Database ready. Create your own account through the app, or sign in locally with username admin and password adminpassword2026 while running in Development mode.'
