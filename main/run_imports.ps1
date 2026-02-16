# Main Import Wrapper Script for PowerShell
# Usage: .\main\run_imports.ps1

Write-Host "Running main imports with main.tfvars..." -ForegroundColor Cyan

Get-Content "$PSScriptRoot\imports_main.sh" | 
    Where-Object { $_ -match '^terraform import' } | 
    ForEach-Object { 
        Write-Host "Executing: $_" -ForegroundColor Gray
        Invoke-Expression "$_ -var-file=main/main.tfvars"
    }

Write-Host "`nImports completed!" -ForegroundColor Green
