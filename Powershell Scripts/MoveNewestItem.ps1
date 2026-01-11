# Get the active File Explorer window path
$shell = New-Object -ComObject Shell.Application
$win = $shell.Windows() | Where-Object { $_.Name -eq "File Explorer" } | Select-Object -First 1

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