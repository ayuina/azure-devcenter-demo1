[CmdletBinding()]
param(
    [string]$name, 
    [string]$email
)

.\Run-Command.ps1 -RunAsUser 'true' -Command "git config --global user.email \"$email\" "
.\Run-Command.ps1 -RunAsUser 'true' -Command "git config --global user.name \"$name\" "

