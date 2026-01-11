# Get the active File Explorer window path
$shell = New-Object -ComObject Shell.Application
$win = $shell.Windows() | Where-Object { $_.Name -eq "File Explorer" } | Select-Object -First 1

if (-not $win) {
    Write-Host "ERROR: No File Explorer window detected."
    exit
}

$target = $win.Document.Folder.Self.Path
Write-Host "Target directory: $target"
