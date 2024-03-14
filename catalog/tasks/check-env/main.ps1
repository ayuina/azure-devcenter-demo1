[CmdletBinding()]
param(
    [string]$name
)

function Main {
    Write-Host "Hello $name !"
    Write-Host ""

    Write-Host '=== Current Location ==='
    Get-Location
    Write-Host ""

    Write-Host '=== PSScriptRoot ==='
    $PSScriptRoot
    Write-Host ""

    Write-Host '=== Environment Variables ==='
    Get-Item Env:
    Write-Host ""

}

Main

