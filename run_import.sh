#!/bin/bash
# Sandbox Import Wrapper Script for Git Bash
# Usage: ./sandbox/run_imports.sh

echo -e "\033[36mRunning sandbox imports with sandbox.tfvars...\033[0m"

while IFS= read -r line; do
    if [[ $line =~ ^terraform\ import ]]; then
        echo -e "\033[90mExecuting: $line\033[0m"
        eval "$line -var-file=sandbox/sandbox.tfvars"
    fi
done < "$(dirname "$0")/imports_sandbox.sh"

echo -e "\033[32m\nImports completed!\033[0m"
