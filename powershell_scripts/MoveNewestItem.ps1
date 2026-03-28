Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

# Get the handle of the currently focused window
$hwnd = [WinAPI]::GetForegroundWindow()

# Get the active File Explorer window path by creating a new shell object
$shell = New-Object -ComObject Shell.Application

# Find the Explorer window matching the foreground HWND
# $win = $shell.Windows() | Where-Object {
#     $_.HWND -eq $hwnd
# }
# Use the .Where() method instead of the pipeline | 
# This is significantly faster for small-to-medium collections
$win = $shell.Windows().Where({ $_.HWND -eq $hwnd }, 'First')

# Critical: Explicitly release the COM object if running in a long-lived session
# (Optional if calling from AHK Run, as the process dies anyway)
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null

# error logging
if (-not $win) {
    Write-Host "ERROR: No File Explorer window detected."
    exit
}

$target = $win.Document.Folder.Self.Path
Write-Host "Target directory: $target"

# ===========================
#  Paths to check
# ===========================
$Screenshots = Join-Path $env:USERPROFILE "Pictures\Screenshots"
$Downloads   = Join-Path $env:USERPROFILE "Downloads"

if (-not (Test-Path $Screenshots)) {
    Write-Host "ERROR: Screenshot folder not found: $Screenshots"
    exit
}

if (-not (Test-Path $Downloads)) {
    Write-Host "ERROR: Downloads folder not found: $Downloads"
    exit
}

# Helper function to get newest file
function Get-NewestFile($path) {
    if (Test-Path $path) {
        return Get-ChildItem $path -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
    return $null
}

# ===========================
#  Get newest screenshot
# ===========================
$latestScreenshot = Get-NewestFile $Screenshots
if ($latestScreenshot) {
    Write-Host "Newest Screenshot: $($latestScreenshot.Name) ($($latestScreenshot.LastWriteTime)))"
} else {
    Write-Host "No screenshots found."
}

# ===========================
#  Get newest download
# ===========================
$latestDownload = Get-NewestFile $Downloads
if ($latestDownload) {
    Write-Host "Newest Download:   $($latestDownload.Name) ($($latestDownload.LastWriteTime))"
} else {
    Write-Host "No downloads found."
}

# ===========================
#  Determine which is newer
# ===========================
$toMove = $null

if ($latestScreenshot -and $latestDownload) {
    if ($latestScreenshot.LastWriteTime -gt $latestDownload.LastWriteTime) {
        $toMove = $latestScreenshot
    } else {
        $toMove = $latestDownload
    }
}
elseif ($latestScreenshot) {
    $toMove = $latestScreenshot
}
elseif ($latestDownload) {
    $toMove = $latestDownload
}

if (-not $toMove) {
    Write-Host "ERROR: No files found in either location."
    exit
}

Write-Host "Made a selection, newest file is: $($toMove.FullName)"


# ===========================
#  Move (Cut & Paste)
# ===========================
try {
    Move-Item -LiteralPath $toMove.FullName -Destination $target -Force
    Write-Host "Successfully moved to: $target"
}
catch {
    Write-Host "ERROR moving file: $_"
}