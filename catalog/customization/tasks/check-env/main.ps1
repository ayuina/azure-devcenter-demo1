[CmdletBinding()]
param(
    [string]$name
)

function Main {
    Write-Host "Hello $name !"
    Write-Host ""

    Write-Host '=== Current Location ==='
    Write-Host @(Get-Location)
    Write-Host ""

    Write-Host '=== PSScriptRoot ==='
    Write-Host "$PSScriptRoot"
    Write-Host ""

    Write-Host '=== Environment Variables ==='
    Get-Item Env:
    Write-Host ""

}

Main

