[CmdletBinding()]
param(
    [string]$name
)

function Main {
    Write-Host "Hello $name !"
    Write-Host ""
    Write-Host '=== Environment Variables ==='
    Get-Item Env:
    Write-Host ""

}

Main

