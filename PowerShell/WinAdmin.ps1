
<# --------------------------------------------------------------
   winclean.ps1
   Two‑column dark‑theme GUI + persistent output textbox
   -------------------------------------------------------------- #>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Suppress all output from the script itself
$null = & {


# ---------- Dark theme ----------
function Set-DarkTheme {
    param([System.Windows.Forms.Form]$Form)

    $Form.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)   # slightly lighter dark
    $global:ForeColor = [System.Drawing.Color]::Blue               # blue text everywhere
    $global:BackColor = $Form.BackColor
}

# ---------- Central output textbox ----------
# This textbox lives at the bottom of the window and is reused by all actions.
$global:OutputBox = New-Object System.Windows.Forms.TextBox
$global:OutputBox.Multiline = $true
$global:OutputBox.ReadOnly   = $true
$global:OutputBox.ScrollBars = 'Both'
$global:OutputBox.Font       = 'Consolas,10'

# Set the background color to a lighter gray
$global:OutputBox.BackColor  = [System.Drawing.Color]::FromArgb(60,60,60)

# Explicitly set the text color to blue for consistency
$global:OutputBox.ForeColor  = [System.Drawing.Color]::Blue

function Write-OutputBox {
    param([string]$Text)
    $global:OutputBox.Text = $Text
    $global:OutputBox.SelectionStart = $global:OutputBox.Text.Length
    $global:OutputBox.ScrollToCaret()
}

# ---------- Helper to run a command and pipe its output ----------
function Run-Command {
    param(
        [string]$Title,
        [scriptblock]$Command
    )
    try {
        $out = & $Command 2>&1 | Out-String
    } catch {
        $out = $_.Exception.Message
    }
    Write-OutputBox "$Title`r`n`r`n$out"
}

# ---------- Individual actions ----------
function Get-SystemInfo   {
    Run-Command -Title 'System Info' -Command {
        Get-ComputerInfo |
            Select-Object OSName,OSVersion,OSArchitecture,
                          CsManufacturer,CsModel,
                          CsProcessor,CsTotalPhysicalMemory |
            Format-List
    }
}

function Get-IPInfo {
    Run-Command -Title 'IP Information' -Command {
        Invoke-RestMethod -Uri 'https://ipinfo.io/json' |
            ConvertTo-Json -Depth 5
    }
}

function Import-Drivers {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq 'OK') {
        $path = $dlg.SelectedPath
        Run-Command -Title "Import Drivers from $path" -Command {
            pnputil /add-driver "$path\*.inf" /subdirs /install
        }
    }
}

function Export-Drivers {
    $save = New-Object System.Windows.Forms.SaveFileDialog
    $save.Filter = 'ZIP Archive|*.zip'
    $save.Title  = 'Export all third-party drivers to ZIP'
    if ($save.ShowDialog() -eq 'OK') {
        $zipPath = $save.FileName
        $tempDir = Join-Path $env:TEMP ('Drivers_' + [guid]::NewGuid())
        md $tempDir | Out-Null

        pnputil /export-driver * $tempDir
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        Remove-Item $tempDir -Recurse -Force

        Run-Command -Title 'Export Complete' -Command {
            "Drivers exported to $zipPath"
        }
    }
}

function Reset-NetworkSettings {
    Run-Command -Title 'Reset Network Settings' -Command {
        netsh int ip reset
        netsh winsock reset
        ipconfig /flushdns
        "Network stack reset – reboot recommended."
    }
}

function Flush-DNS {
    Run-Command -Title 'Flush DNS Cache' -Command { ipconfig /flushdns }
}

function ScanHealth {
    Run-Command -Title 'DISM ScanHealth' -Command { DISM /Online /Cleanup-Image /ScanHealth }
}

function RestoreHealth {
    Run-Command -Title 'DISM RestoreHealth' -Command { DISM /Online /Cleanup-Image /RestoreHealth }
}

function ScanAndRepair {
    # SFC needs elevation; we launch it via Start-Process so the UI stays responsive
    $title = 'SFC Scan & Repair (sfc /scannow)'
    try {
        $proc = Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
                               -ArgumentList '/scannow' `
                               -Verb RunAs `
                               -NoNewWindow `
                               -RedirectStandardOutput "$env:TEMP\sfc_out.txt" `
                               -RedirectStandardError  "$env:TEMP\sfc_err.txt" `
                               -PassThru
        $proc.WaitForExit()

        $out = Get-Content -Path "$env:TEMP\sfc_out.txt" -Raw
        $err = Get-Content -Path "$env:TEMP\sfc_err.txt" -Raw
        $combined = if ($err) { "$out`r`n--- Errors ---`r`n$err" } else { $out }

        Write-OutputBox "$title`r`n`r`n$combined"
    } catch {
        Write-OutputBox "$title`r`n`r`nFailed to start SFC: $($_.Exception.Message)"
    } finally {
        Remove-Item "$env:TEMP\sfc_out.txt","$env:TEMP\sfc_err.txt" -ErrorAction SilentlyContinue
    }
}

function Run-CleanMgr {
    Run-Command -Title 'Disk Cleanup (cleanmgr.exe /c)' -Command {
        & "$env:SystemRoot\System32\cleanmgr.exe" /c
    }
}

# ---------- Build the GUI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'WinClean – Windows Maintenance Toolkit'


# ---- Set the window icon to the built‑in Disk Cleanup icon ----
$cleanMgrPath = "$env:SystemRoot\System32\cleanmgr.exe"
if (Test-Path $cleanMgrPath) {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($cleanMgrPath)
} else {
    Write-OutputBox "Warning: cleanmgr.exe not found; using default window icon."
}

$form.Size = New-Object System.Drawing.Size(605,500)   # width × height
$form.StartPosition = 'CenterScreen'

Set-DarkTheme -Form $form

# Helper to create uniformly styled buttons
function New-Button {
    param(
        [string]$Text,
        [scriptblock]$OnClick,
        [int]$Left,
        [int]$Top
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Width  = 260
    $btn.Height = 35
    $btn.Left   = $Left
    $btn.Top    = $Top
    $btn.FlatStyle = 'Flat'
    $btn.ForeColor = $global:ForeColor
    $btn.BackColor = [System.Drawing.Color]::FromArgb(60,60,60)
    $btn.Add_Click($OnClick)
    $form.Controls.Add($btn)
    return $btn
}

# ----- Layout calculations -----
$margin   = 20                       # distance from window edges
$colGap   = 30                       # space between the two columns
$stepV    = 45                       # vertical distance between buttons

# Column X coordinates
$leftX  = $margin
$rightX = $margin + 260 + $colGap

# Starting Y coordinate for both columns
$startY = $margin

# ---- LEFT COLUMN (System Info … Reset Network) ----
New-Button -Text 'System Info'               -OnClick { Get-SystemInfo }          -Left $leftX -Top ($startY + $stepV*0)
New-Button -Text 'IP Info'                   -OnClick { Get-IPInfo }              -Left $leftX -Top ($startY + $stepV*1)
New-Button -Text 'Import Drivers'            -OnClick { Import-Drivers }           -Left $leftX -Top ($startY + $stepV*2)
New-Button -Text 'Export Drivers'            -OnClick { Export-Drivers }           -Left $leftX -Top ($startY + $stepV*3)
New-Button -Text 'Reset Network Settings'    -OnClick { Reset-NetworkSettings }    -Left $leftX -Top ($startY + $stepV*4)

# ---- RIGHT COLUMN (Flush DNS … Clean Up) ----
New-Button -Text 'Flush DNS'                 -OnClick { Flush-DNS }                -Left $rightX -Top ($startY + $stepV*0)
New-Button -Text 'DISM ScanHealth'           -OnClick { ScanHealth }               -Left $rightX -Top ($startY + $stepV*1)
New-Button -Text 'DISM RestoreHealth'        -OnClick { RestoreHealth }            -Left $rightX -Top ($startY + $stepV*2)
New-Button -Text 'SFC Scan & Repair'         -OnClick { ScanAndRepair }            -Left $rightX -Top ($startY + $stepV*3)
New-Button -Text 'Clean Up (Disk Cleanup)'   -OnClick { Run-CleanMgr }             -Left $rightX -Top ($startY + $stepV*4)

# ----- OUTPUT TEXTBOX (spans both columns, anchored to bottom) -----
$txtHeight = 180
$global:OutputBox.Width  = $form.ClientSize.Width - 2*$margin
$global:OutputBox.Height = $txtHeight
$global:OutputBox.Left   = $margin
$global:OutputBox.Top    = $form.ClientSize.Height - $txtHeight - $margin
$global:OutputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor `
                           [System.Windows.Forms.AnchorStyles]::Left -bor `
                           [System.Windows.Forms.AnchorStyles]::Right

$form.Controls.Add($global:OutputBox)

# Show the form
[void]$form.ShowDialog()

} 2>&1 | Out-Null