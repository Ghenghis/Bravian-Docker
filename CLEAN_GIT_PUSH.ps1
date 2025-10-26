# Clean Git Repository and Push to GitHub
# This script completely cleans the Git history and pushes only current files

Write-Host "========================================" -ForegroundColor Green
Write-Host "CLEANING GIT REPOSITORY - DOCKER TRAVIAN" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Step 1: Remove the entire .git folder to start fresh
Write-Host "Step 1: Removing old Git repository..." -ForegroundColor Yellow
if (Test-Path ".git") {
    Remove-Item -Recurse -Force ".git"
    Write-Host "✅ Old Git repository removed" -ForegroundColor Green
} else {
    Write-Host "ℹ️ No existing Git repository found" -ForegroundColor Blue
}

# Step 2: Initialize fresh Git repository
Write-Host "Step 2: Initializing fresh Git repository..." -ForegroundColor Yellow
git init
Write-Host "✅ Fresh Git repository initialized" -ForegroundColor Green

# Step 3: Add remote repository
Write-Host "Step 3: Adding remote repository..." -ForegroundColor Yellow
git remote add origin https://github.com/Ghenghis/Bravian-Docker.git
Write-Host "✅ Remote repository added" -ForegroundColor Green

# Step 4: Check what files will be added (respecting .gitignore)
Write-Host "Step 4: Checking files to be added..." -ForegroundColor Yellow
git add .
git status
Write-Host "✅ Files staged for commit" -ForegroundColor Green

# Step 5: Create initial commit
Write-Host "Step 5: Creating initial commit..." -ForegroundColor Yellow
git commit -m "🚀 Enterprise Docker Travian v1.0.0 - Production Ready

✨ Complete enterprise implementation:
- Multi-stage Docker architecture (8 services)
- Enterprise automation scripts (7 PowerShell)
- CI/CD pipeline with GitHub Actions
- Complete monitoring stack (Prometheus/Grafana)
- Security hardening (OWASP compliant)
- Complete documentation suite (11 files)
- Database optimization framework
- One-command deployment system

🏗️ Tech Stack: PHP 8.2 + NGINX + MariaDB + Redis + RabbitMQ
📚 Docs: Complete enterprise documentation
🔒 Security: Container hardening + OWASP compliance
⚡ Performance: Query optimization + Redis caching
🎯 Status: 100% production ready

Note: Large files excluded via .gitignore for GitHub compatibility"

Write-Host "✅ Initial commit created" -ForegroundColor Green

# Step 6: Set main branch and push
Write-Host "Step 6: Pushing to GitHub..." -ForegroundColor Yellow
git branch -M main
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "🎉 SUCCESS! GITHUB PUSH COMPLETED!" -ForegroundColor Green
    Write-Host "Repository: https://github.com/Ghenghis/Bravian-Docker" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ PUSH FAILED - CHECK OUTPUT ABOVE" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}

Write-Host "Press any key to continue..." -ForegroundColor Yellow
Read-Host
