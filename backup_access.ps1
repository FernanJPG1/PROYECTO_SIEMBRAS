# backup_access.ps1
# Script para respaldar la base de datos de Microsoft Access automáticamente.

$dbName = "bmempresarial2021.accdb"
$sourcePath = "C:\Users\lvalencia\Desktop\PROYECTO SIEMBRAS\$dbName"
$backupDir = "C:\Users\lvalencia\Desktop\PROYECTO SIEMBRAS\backups"

# Crear directorio de backups si no existe
if (!(Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$backupDir\${dbName}_backup_$timestamp.accdb"

# Copiar el archivo
try {
    Copy-Item -Path $sourcePath -Destination $backupPath -ErrorAction Stop
    Write-Host "✅ Backup exitoso: $backupPath" -ForegroundColor Green
    
    # Rotación: Mantener solo los últimos 7 backups
    $backups = Get-ChildItem -Path $backupDir -Filter "*.accdb" | Sort-Object CreationTime -Descending
    if ($backups.Count -gt 7) {
        for ($i = 7; $i -lt $backups.Count; $i++) {
            Remove-Item $backups[$i].FullName -Force
            Write-Host "🗑️ Backup antiguo eliminado: $($backups[$i].Name)" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "❌ Error al hacer el backup de la base de datos." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
