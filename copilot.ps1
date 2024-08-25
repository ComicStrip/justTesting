# Check if the script is running as administrator
if (![bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges. Please run it as an administrator." -ForegroundColor Red
    exit
}

# Remove the Microsoft Windows Copilot package
try {
    $copilotPackage = Get-AppxPackage *Microsoft.Windows.Copilot* -ErrorAction Stop
    if ($copilotPackage) {
        Write-Host "Removing Microsoft Windows Copilot package..."
        Remove-AppxPackage $copilotPackage -ErrorAction Stop
        Write-Host "Microsoft Windows Copilot package removed successfully." -ForegroundColor Green
    } else {
        Write-Host "No Microsoft Windows Copilot package found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error occurred while trying to remove Microsoft Windows Copilot package: $_" -ForegroundColor Red
}

# Disable Cortana by modifying the registry
try {
    Write-Host "Disabling Cortana..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -ErrorAction Stop
    Write-Host "Cortana has been disabled successfully." -ForegroundColor Green
} catch {
    Write-Host "Error occurred while trying to disable Cortana: $_" -ForegroundColor Red
}
