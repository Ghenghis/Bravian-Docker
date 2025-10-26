# Docker Travian Backup System
# Automated backup solution for database, files, and configurations

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupType = "full",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupLocation = "",
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$Compress = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verify = $true
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$DefaultBackupLocation = Join-Path $ProjectRoot "backups"
$BackupLocation = if ($BackupLocation) { $BackupLocation } else { $DefaultBackupLocation }
$LogFile = Join-Path $ProjectRoot "logs\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure directories exist
@($BackupLocation, (Split-Path -Parent $LogFile)) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

# Error handling
trap {
    Write-Log "BACKUP FAILED: $($_.Exception.Message)" "ERROR"
    Write-Log "Check log file: $LogFile" "ERROR"
    exit 1
}

Write-Log "Starting Docker Travian backup process..."
Write-Log "Backup Type: $BackupType"
Write-Log "Backup Location: $BackupLocation"
Write-Log "Retention Days: $RetentionDays"

# Check if Docker services are running
function Test-DockerServices {
    Write-Log "Checking Docker services status..."
    
    try {
        $Services = docker-compose ps --services --filter "status=running"
        $RunningServices = $Services | Measure-Object | Select-Object -ExpandProperty Count
        
        if ($RunningServices -eq 0) {
            Write-Log "No Docker services are running. Starting services for backup..." "WARN"
            docker-compose up -d
            Start-Sleep -Seconds 30
        }
        
        Write-Log "Docker services are ready for backup"
    }
    catch {
        Write-Log "Failed to check Docker services: $($_.Exception.Message)" "ERROR"
        throw "Docker services unavailable"
    }
}

# Backup database
function Backup-Database {
    Write-Log "Starting database backup..."
    
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $DbBackupFile = Join-Path $BackupLocation "database-$BackupDate.sql"
    
    try {
        # Create database dump
        $DumpCommand = "docker-compose exec -T mysql mysqldump -u travian -ptravian123 --single-transaction --routines --triggers travian"
        Invoke-Expression $DumpCommand | Out-File -FilePath $DbBackupFile -Encoding UTF8
        
        if (-not (Test-Path $DbBackupFile)) {
            throw "Database backup file was not created"
        }
        
        $BackupSize = (Get-Item $DbBackupFile).Length
        Write-Log "Database backup completed: $DbBackupFile ($([math]::Round($BackupSize/1MB, 2)) MB)"
        
        # Compress if requested
        if ($Compress) {
            $CompressedFile = "$DbBackupFile.gz"
            
            # Use 7-Zip if available, otherwise use PowerShell compression
            if (Get-Command 7z -ErrorAction SilentlyContinue) {
                7z a -tgzip $CompressedFile $DbBackupFile
                Remove-Item $DbBackupFile
                $DbBackupFile = $CompressedFile
            }
            else {
                Compress-Archive -Path $DbBackupFile -DestinationPath "$DbBackupFile.zip"
                Remove-Item $DbBackupFile
                $DbBackupFile = "$DbBackupFile.zip"
            }
            
            Write-Log "Database backup compressed: $DbBackupFile"
        }
        
        # Verify backup if requested
        if ($Verify) {
            Test-BackupIntegrity -BackupFile $DbBackupFile -Type "database"
        }
        
        return $DbBackupFile
    }
    catch {
        Write-Log "Database backup failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Backup application files
function Backup-ApplicationFiles {
    Write-Log "Starting application files backup..."
    
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $FilesBackupFile = Join-Path $BackupLocation "files-$BackupDate.tar.gz"
    
    try {
        # Define directories to backup
        $BackupDirs = @(
            "src",
            "config",
            "Templates",
            "Admin",
            "GameEngine",
            ".env"
        )
        
        $ExistingDirs = $BackupDirs | Where-Object { Test-Path (Join-Path $ProjectRoot $_) }
        
        if ($ExistingDirs.Count -eq 0) {
            Write-Log "No application files found to backup" "WARN"
            return $null
        }
        
        # Create tar archive
        $TarCommand = "tar -czf `"$FilesBackupFile`" -C `"$ProjectRoot`" " + ($ExistingDirs -join " ")
        Invoke-Expression $TarCommand
        
        if (-not (Test-Path $FilesBackupFile)) {
            throw "Application files backup was not created"
        }
        
        $BackupSize = (Get-Item $FilesBackupFile).Length
        Write-Log "Application files backup completed: $FilesBackupFile ($([math]::Round($BackupSize/1MB, 2)) MB)"
        
        # Verify backup if requested
        if ($Verify) {
            Test-BackupIntegrity -BackupFile $FilesBackupFile -Type "files"
        }
        
        return $FilesBackupFile
    }
    catch {
        Write-Log "Application files backup failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Backup Docker volumes
function Backup-DockerVolumes {
    Write-Log "Starting Docker volumes backup..."
    
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $VolumesBackupDir = Join-Path $BackupLocation "volumes-$BackupDate"
    
    try {
        New-Item -ItemType Directory -Path $VolumesBackupDir -Force | Out-Null
        
        # Get list of volumes
        $Volumes = docker volume ls --filter "name=docker-travian" --format "{{.Name}}"
        
        if (-not $Volumes) {
            Write-Log "No Docker volumes found to backup" "WARN"
            return $null
        }
        
        foreach ($Volume in $Volumes) {
            Write-Log "Backing up volume: $Volume"
            
            $VolumeBackupFile = Join-Path $VolumesBackupDir "$Volume.tar.gz"
            
            $BackupCommand = @"
docker run --rm -v ${Volume}:/data -v "${VolumesBackupDir}:/backup" alpine tar czf "/backup/$Volume.tar.gz" -C /data .
"@
            
            Invoke-Expression $BackupCommand
            
            if (Test-Path $VolumeBackupFile) {
                $BackupSize = (Get-Item $VolumeBackupFile).Length
                Write-Log "Volume $Volume backed up: $([math]::Round($BackupSize/1MB, 2)) MB"
            }
            else {
                Write-Log "Failed to backup volume: $Volume" "WARN"
            }
        }
        
        Write-Log "Docker volumes backup completed: $VolumesBackupDir"
        return $VolumesBackupDir
    }
    catch {
        Write-Log "Docker volumes backup failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Backup configurations
function Backup-Configurations {
    Write-Log "Starting configurations backup..."
    
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $ConfigBackupFile = Join-Path $BackupLocation "config-$BackupDate.tar.gz"
    
    try {
        # Define configuration files to backup
        $ConfigFiles = @(
            "docker-compose.yml",
            "docker-compose.override.yml",
            ".env",
            ".env.example",
            "Makefile",
            "docker/",
            "scripts/",
            "docs/"
        )
        
        $ExistingConfigs = $ConfigFiles | Where-Object { Test-Path (Join-Path $ProjectRoot $_) }
        
        if ($ExistingConfigs.Count -eq 0) {
            Write-Log "No configuration files found to backup" "WARN"
            return $null
        }
        
        # Create tar archive
        $TarCommand = "tar -czf `"$ConfigBackupFile`" -C `"$ProjectRoot`" " + ($ExistingConfigs -join " ")
        Invoke-Expression $TarCommand
        
        if (-not (Test-Path $ConfigBackupFile)) {
            throw "Configuration backup was not created"
        }
        
        $BackupSize = (Get-Item $ConfigBackupFile).Length
        Write-Log "Configuration backup completed: $ConfigBackupFile ($([math]::Round($BackupSize/1KB, 2)) KB)"
        
        return $ConfigBackupFile
    }
    catch {
        Write-Log "Configuration backup failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Test backup integrity
function Test-BackupIntegrity {
    param(
        [string]$BackupFile,
        [string]$Type
    )
    
    Write-Log "Verifying backup integrity: $BackupFile"
    
    try {
        switch ($Type) {
            "database" {
                if ($BackupFile -match "\.(gz|zip)$") {
                    # Test compressed file integrity
                    if ($BackupFile -match "\.gz$") {
                        gzip -t $BackupFile
                    }
                    elseif ($BackupFile -match "\.zip$") {
                        $TestResult = Test-Path $BackupFile
                        if (-not $TestResult) { throw "Zip file test failed" }
                    }
                }
                else {
                    # Test SQL file syntax
                    $Content = Get-Content $BackupFile -First 10
                    if ($Content -notmatch "CREATE TABLE|INSERT INTO|mysqldump") {
                        throw "Database backup does not contain expected SQL content"
                    }
                }
            }
            "files" {
                # Test tar.gz integrity
                tar -tzf $BackupFile | Out-Null
            }
        }
        
        Write-Log "Backup integrity verified: $BackupFile" "SUCCESS"
    }
    catch {
        Write-Log "Backup integrity check failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Clean old backups
function Remove-OldBackups {
    Write-Log "Cleaning old backups (retention: $RetentionDays days)..."
    
    try {
        $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $OldBackups = Get-ChildItem -Path $BackupLocation -File | Where-Object { $_.LastWriteTime -lt $CutoffDate }
        
        if ($OldBackups) {
            foreach ($Backup in $OldBackups) {
                Remove-Item $Backup.FullName -Force
                Write-Log "Removed old backup: $($Backup.Name)"
            }
            
            Write-Log "Cleaned $($OldBackups.Count) old backup(s)"
        }
        else {
            Write-Log "No old backups to clean"
        }
    }
    catch {
        Write-Log "Failed to clean old backups: $($_.Exception.Message)" "WARN"
    }
}

# Create backup manifest
function New-BackupManifest {
    param([array]$BackupFiles)
    
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $ManifestFile = Join-Path $BackupLocation "manifest-$BackupDate.json"
    
    $Manifest = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        backup_type = $BackupType
        retention_days = $RetentionDays
        files = @()
    }
    
    foreach ($File in $BackupFiles) {
        if ($File -and (Test-Path $File)) {
            $FileInfo = Get-Item $File
            $Manifest.files += @{
                name = $FileInfo.Name
                path = $FileInfo.FullName
                size = $FileInfo.Length
                hash = (Get-FileHash $File -Algorithm SHA256).Hash
                created = $FileInfo.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    }
    
    $Manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath $ManifestFile -Encoding UTF8
    Write-Log "Backup manifest created: $ManifestFile"
    
    return $ManifestFile
}

# Main backup execution
function Start-BackupProcess {
    $BackupFiles = @()
    
    try {
        # Check Docker services
        Test-DockerServices
        
        # Perform backups based on type
        switch ($BackupType.ToLower()) {
            "database" {
                $BackupFiles += Backup-Database
            }
            "files" {
                $BackupFiles += Backup-ApplicationFiles
            }
            "volumes" {
                $BackupFiles += Backup-DockerVolumes
            }
            "config" {
                $BackupFiles += Backup-Configurations
            }
            "full" {
                $BackupFiles += Backup-Database
                $BackupFiles += Backup-ApplicationFiles
                $BackupFiles += Backup-DockerVolumes
                $BackupFiles += Backup-Configurations
            }
            default {
                throw "Unknown backup type: $BackupType"
            }
        }
        
        # Create manifest
        $ManifestFile = New-BackupManifest -BackupFiles $BackupFiles
        
        # Clean old backups
        Remove-OldBackups
        
        # Calculate total backup size
        $TotalSize = 0
        $BackupFiles | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object {
            $TotalSize += (Get-Item $_).Length
        }
        
        Write-Log "Backup process completed successfully!" "SUCCESS"
        Write-Log "Total backup size: $([math]::Round($TotalSize/1MB, 2)) MB"
        Write-Log "Backup location: $BackupLocation"
        Write-Log "Manifest file: $ManifestFile"
        
        return @{
            success = $true
            files = $BackupFiles
            manifest = $ManifestFile
            total_size = $TotalSize
        }
    }
    catch {
        Write-Log "Backup process failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Execute backup
try {
    $Result = Start-BackupProcess
    
    Write-Log "Backup completed successfully!"
    Write-Log "Log file: $LogFile"
    
    exit 0
}
catch {
    Write-Log "Backup failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
