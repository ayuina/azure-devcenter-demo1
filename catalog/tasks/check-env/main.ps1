[CmdletBinding()]
param(
    [string]$name
)

function Main {
    Write-Host "Hello $name !"
}

Main

