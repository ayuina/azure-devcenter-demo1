[CmdletBinding()]
param(
    [string]$name, 
    [string]$email
)

$gitConfigScript = @"
git config --global user.email "$email"
git config --global user.name "$name"
"@

.\Run-Command.ps1 -RunAsUser 'true' -Command $gitConfigScript

