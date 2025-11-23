# wincleanup.ps1 - Complete Windows Maintenance Toolkit Script
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Initialize log
$logFile = "$env:USERPROFILE\wincleanup.log"
$LogStream = [System.IO.StreamWriter]::new($logFile, $true)

function Log-Write {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogStream.WriteLine("$timestamp - $Message")
    $LogStream.Flush()
}

# Define Run-Command to execute shell commands and capture output
function Run-Command {
    param(
        [string]$Title,
        [scriptblock]$Command
    )
    try {
        $output = & $Command 2>&1 | Out-String
    } catch {
        $output = $_.Exception.Message
    }
    # Use subexpression to delimit variable
    Append-Output "$($Title):`n$output"
    Update-Status "$($Title) completed." 100
}

# Set up main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'WinAdmin - Windows Toolkit'
# Set the window icon to Disk Cleanup icon
$cleanMgrPath = "$env:SystemRoot\System32\cleanmgr.exe"
if (Test-Path $cleanMgrPath) {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($cleanMgrPath)
} else {
    Write-OutputBox "Warning: cleanmgr.exe not found; using default window icon."
}

$form.Size = New-Object System.Drawing.Size(415, 500)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)

# Progress bar below buttons
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Width = 380
$ProgressBar.Height= 20
$ProgressBar.Minimum = 0
$ProgressBar.Maximum = 100
$ProgressBar.Value = 0
$ProgressBar.Style = 'Continuous'
$ProgressBar.ForeColor = [System.Drawing.Color]::Blue
$ProgressBar.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$ProgressBar.Left = 10
$ProgressBar.Top = 215
$form.Controls.Add($ProgressBar)

# Status label
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready"
$StatusLabel.ForeColor = [System.Drawing.Color]::Blue
$StatusLabel.Left = 10
$StatusLabel.Top = 250
$StatusLabel.Width = 415
$form.Controls.Add($StatusLabel)

# Output textbox at bottom
$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Multiline = $true
$OutputBox.ReadOnly = $true
$OutputBox.ScrollBars = 'Both'
$OutputBox.Font = 'Consolas,10'
$OutputBox.ForeColor = [System.Drawing.Color]::Blue
$OutputBox.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$OutputBox.Width = 380
$OutputBox.Height = 155
$OutputBox.Left = 10
$OutputBox.Top = 275
$OutputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($OutputBox)

# Helper functions for UI updates
function Write-Log {
    param([string]$Message)
    Log-Write $Message
}

function Update-Status {
    param([string]$Message, [int]$progress=0)
    $StatusLabel.Text = $Message
    if ($progress -ge 0 -and $progress -le 100) {
        $ProgressBar.Value = $progress
    }
    Write-Log $Message
}

function Append-Output {
    param([string]$Text)
    $OutputBox.AppendText("$Text`r`n")
    $OutputBox.SelectionStart = $OutputBox.Text.Length
    $OutputBox.ScrollToCaret()
}

# Define all task functions
function Get-SystemInfo {
    Update-Status "Gathering System Info..."
    for ($i=0; $i -le 100; $i+=20) {
        Start-Sleep -Milliseconds 100
        Update-Status "Gathering System Info..." $i
    }
    $info = Get-ComputerInfo | 
            Select-Object OSName, OSVersion, OSArchitecture,
                          CsManufacturer, CsModel,
                          CsProcessor, CsTotalPhysicalMemory |
            Format-List | Out-String
    Append-Output $info
    Update-Status "System Info Retrieved." 100
}

function Get-IPInfo {
    Update-Status "Gathering IP Info..."
    for ($i=0; $i -le 100; $i+=20) {
        Start-Sleep -Milliseconds 100
        Update-Status "Gathering IP Info..." $i
    }
    $ipInfo = Invoke-RestMethod -Uri 'https://ipinfo.io/json' | ConvertTo-Json -Depth 5
    Append-Output $ipInfo
    Update-Status "IP Info Retrieved." 100
}

function Import-Drivers {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq 'OK') {
        $path = $dlg.SelectedPath
        Update-Status "Importing drivers from $path..."
        for ($i=0; $i -le 100; $i+=10) {
            Start-Sleep -Milliseconds 200
            Update-Status "Importing drivers..." $i
        }
        Run-Command -Title "Importing Drivers" -Command { pnputil /add-driver "$using:path\*.inf" /subdirs /install }
        Append-Output "Drivers imported from $using:path."
        Update-Status "Driver import completed." 100
    }
}

function Export-Drivers {
    $saveDlg = New-Object System.Windows.Forms.SaveFileDialog
    $saveDlg.Filter = 'ZIP Archive|*.zip'
    $saveDlg.Title = 'Export all third-party drivers to ZIP'
    if ($saveDlg.ShowDialog() -eq 'OK') {
        $zipPath = $saveDlg.FileName
        Update-Status "Exporting drivers to $zipPath..."
        for ($i=0; $i -le 100; $i+=10) {
            Start-Sleep -Milliseconds 200
            Update-Status "Exporting drivers..." $i
        }
        $tempDir = Join-Path $env:TEMP ('Drivers_' + [guid]::NewGuid())
        md $tempDir | Out-Null
        Run-Command -Title 'Export Drivers' -Command { pnputil /export-driver * $using:tempDir }
        Compress-Archive -Path "$using:tempDir\*" -DestinationPath $using:zipPath -Force
        Remove-Item $using:tempDir -Recurse -Force
        Append-Output "Drivers exported to $using:zipPath."
        Update-Status "Driver export completed." 100
    }
}

function Reset-NetworkSettings {
    Update-Status "Resetting network settings..."
    for ($i=0; $i -le 100; $i+=20) {
        Start-Sleep -Milliseconds 100
        Update-Status "Resetting network..." $i
    }
    Run-Command -Title "Resetting Network" -Command {
        netsh int ip reset
        netsh winsock reset
        ipconfig /flushdns
    }
    Append-Output "Network settings reset. Reboot recommended."
    Update-Status "Network reset complete." 100
}

function Flush-DNS {
    Update-Status "Flushing DNS cache..."
    for ($i=0; $i -le 100; $i+=20) {
        Start-Sleep -Milliseconds 100
        Update-Status "Flushing DNS..." $i
    }
    Run-Command -Title "Flush DNS" -Command { ipconfig /flushdns }
    Append-Output "DNS cache flushed."
    Update-Status "DNS cache flushed." 100
}

function ScanHealth {
    Update-Status "Starting DISM /ScanHealth..."
    for ($i=0; $i -le 100; $i+=10) {
        Start-Sleep -Milliseconds 200
        Update-Status "DISM /ScanHealth..." $i
    }
    $result = DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-String
    Append-Output $result
    Update-Status "DISM /ScanHealth completed." 100
}

function RestoreHealth {
    Update-Status "Starting DISM /RestoreHealth..."
    for ($i=0; $i -le 100; $i+=10) {
        Start-Sleep -Milliseconds 200
        Update-Status "DISM /RestoreHealth..." $i
    }
    $result = DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
    Append-Output $result
    Update-Status "DISM /RestoreHealth completed." 100
}

function ScanAndRepair {
    Update-Status "Starting SFC scan..."
    for ($i=0; $i -le 100; $i+=10) {
        Start-Sleep -Milliseconds 200
        Update-Status "SFC Scan..." $i
    }
    $result = & { sfc /scannow } 2>&1 | Out-String
    Append-Output $result
    Update-Status "SFC scan & repair completed." 100
}

# Create buttons and assign click handlers

# Left column buttons
$btnSystemInfo = New-Object System.Windows.Forms.Button
$btnSystemInfo.Text = "System Info"
$btnSystemInfo.Width = 180
$btnSystemInfo.Height = 30
$btnSystemInfo.Left = 10
$btnSystemInfo.Top = 10
$btnSystemInfo.FlatStyle = 'Flat'
$btnSystemInfo.ForeColor = [System.Drawing.Color]::Blue
$btnSystemInfo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnSystemInfo.Add_Click({ Get-SystemInfo })
$form.Controls.Add($btnSystemInfo)

$btnIPInfo = New-Object System.Windows.Forms.Button
$btnIPInfo.Text = "IP Info"
$btnIPInfo.Width = 180
$btnIPInfo.Height = 30
$btnIPInfo.Left = 10
$btnIPInfo.Top = 50
$btnIPInfo.FlatStyle = 'Flat'
$btnIPInfo.ForeColor = [System.Drawing.Color]::Blue
$btnIPInfo.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnIPInfo.Add_Click({ Get-IPInfo })
$form.Controls.Add($btnIPInfo)

$btnImportDrivers = New-Object System.Windows.Forms.Button
$btnImportDrivers.Text = "Import Drivers"
$btnImportDrivers.Width = 180
$btnImportDrivers.Height = 30
$btnImportDrivers.Left = 10
$btnImportDrivers.Top = 90
$btnImportDrivers.FlatStyle = 'Flat'
$btnImportDrivers.ForeColor = [System.Drawing.Color]::Blue
$btnImportDrivers.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnImportDrivers.Add_Click({ Import-Drivers })
$form.Controls.Add($btnImportDrivers)

$btnExportDrivers = New-Object System.Windows.Forms.Button
$btnExportDrivers.Text = "Export Drivers"
$btnExportDrivers.Width = 180
$btnExportDrivers.Height = 30
$btnExportDrivers.Left = 10
$btnExportDrivers.Top = 130
$btnExportDrivers.FlatStyle = 'Flat'
$btnExportDrivers.ForeColor = [System.Drawing.Color]::Blue
$btnExportDrivers.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnExportDrivers.Add_Click({ Export-Drivers })
$form.Controls.Add($btnExportDrivers)

$btnResetNetwork = New-Object System.Windows.Forms.Button
$btnResetNetwork.Text = "Reset Network"
$btnResetNetwork.Width = 180
$btnResetNetwork.Height = 30
$btnResetNetwork.Left = 10
$btnResetNetwork.Top = 170
$btnResetNetwork.FlatStyle = 'Flat'
$btnResetNetwork.ForeColor = [System.Drawing.Color]::Blue
$btnResetNetwork.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnResetNetwork.Add_Click({ Reset-NetworkSettings })
$form.Controls.Add($btnResetNetwork)

# Right column buttons
$btnFlushDNS = New-Object System.Windows.Forms.Button
$btnFlushDNS.Text = "Flush DNS"
$btnFlushDNS.Width = 180
$btnFlushDNS.Height = 30
$btnFlushDNS.Left = 210
$btnFlushDNS.Top = 10
$btnFlushDNS.FlatStyle = 'Flat'
$btnFlushDNS.ForeColor = [System.Drawing.Color]::Blue
$btnFlushDNS.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnFlushDNS.Add_Click({ Flush-DNS })
$form.Controls.Add($btnFlushDNS)

$btnDISMScan = New-Object System.Windows.Forms.Button
$btnDISMScan.Text = "DISM ScanHealth"
$btnDISMScan.Width = 180
$btnDISMScan.Height = 30
$btnDISMScan.Left = 210
$btnDISMScan.Top = 50
$btnDISMScan.FlatStyle = 'Flat'
$btnDISMScan.ForeColor = [System.Drawing.Color]::Blue
$btnDISMScan.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnDISMScan.Add_Click({ ScanHealth })
$form.Controls.Add($btnDISMScan)

$btnDISMRestore = New-Object System.Windows.Forms.Button
$btnDISMRestore.Text = "DISM RestoreHealth"
$btnDISMRestore.Width = 180
$btnDISMRestore.Height = 30
$btnDISMRestore.Left = 210
$btnDISMRestore.Top = 90
$btnDISMRestore.FlatStyle = 'Flat'
$btnDISMRestore.ForeColor = [System.Drawing.Color]::Blue
$btnDISMRestore.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnDISMRestore.Add_Click({ RestoreHealth })
$form.Controls.Add($btnDISMRestore)

$btnSFC = New-Object System.Windows.Forms.Button
$btnSFC.Text = "SFC Scan & Repair"
$btnSFC.Width = 180
$btnSFC.Height = 30
$btnSFC.Left = 210
$btnSFC.Top = 130
$btnSFC.FlatStyle = 'Flat'
$btnSFC.ForeColor = [System.Drawing.Color]::Blue
$btnSFC.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnSFC.Add_Click({ ScanAndRepair })
$form.Controls.Add($btnSFC)

$btnSFC = New-Object System.Windows.Forms.Button
$btnSFC.Text = "Disk Cleanup"
$btnSFC.Width = 180
$btnSFC.Height = 30
$btnSFC.Left = 210
$btnSFC.Top = 170
$btnSFC.FlatStyle = 'Flat'
$btnSFC.ForeColor = [System.Drawing.Color]::Blue
$btnSFC.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
$btnSFC.Add_Click({ Start-Process cleanmgr.exe })
$form.Controls.Add($btnSFC)

# Show form
$null = $form.ShowDialog()

# Close log
$LogStream.Close()