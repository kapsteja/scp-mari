# Sandbox Import Wrapper Script for PowerShell
# Usage: .\sandbox\run_imports.ps1

Write-Host "Running sandbox imports with sandbox.tfvars..." -ForegroundColor Cyan

Get-Content "$PSScriptRoot\imports_sandbox.sh" | 
    Where-Object { $_ -match '^terraform import' } | 
    ForEach-Object { 
        Write-Host "Executing: $_" -ForegroundColor Gray
        Invoke-Expression "$_ -var-file=sandbox/sandbox.tfvars"
    }

Write-Host "`nImports completed!" -ForegroundColor Green
