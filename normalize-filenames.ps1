<#
.SYNOPSIS
    Remove duplicate files caused by NFD (macOS) vs NFC (Windows) Unicode encoding.
.NOTES
    Requires no runtime - runs on any Windows with PowerShell.
    Right-click -> "Run with PowerShell" or run from terminal.
.PARAMETER Path
    Target directory path.
.PARAMETER Delete
    Actually delete files (default: dry-run preview only).
.PARAMETER KeepNfd
    Keep NFD copies, delete NFC copies (default: keep NFC).
.EXAMPLE
    .\normalize-filenames.ps1 "D:\downloads"
    .\normalize-filenames.ps1 "D:\downloads" -Delete
    .\normalize-filenames.ps1 "D:\downloads" -Delete -KeepNfd
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,
    [switch]$Delete,
    [switch]$KeepNfd
)

$Ordinal = [System.StringComparison]::Ordinal

function Test-IsNfd([string]$Name) {
    $nfc = $Name.Normalize([System.Text.NormalizationForm]::FormC)
    $nfd = $Name.Normalize([System.Text.NormalizationForm]::FormD)
    $eqNfd = [System.String]::Equals($Name, $nfd, $Ordinal)
    $eqNfc = [System.String]::Equals($Name, $nfc, $Ordinal)
    return $eqNfd -and -not $eqNfc
}

function Test-IsNfc([string]$Name) {
    $nfc = $Name.Normalize([System.Text.NormalizationForm]::FormC)
    $nfd = $Name.Normalize([System.Text.NormalizationForm]::FormD)
    $eqNfd = [System.String]::Equals($Name, $nfd, $Ordinal)
    $eqNfc = [System.String]::Equals($Name, $nfc, $Ordinal)
    return $eqNfc -and -not $eqNfd
}

# ---- main ----
$resolvedPath = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path $resolvedPath -PathType Container)) {
    Write-Host "ERROR: directory not found: $resolvedPath" -ForegroundColor Red
    exit 1
}

$items = Get-ChildItem -LiteralPath $resolvedPath -File

$nfdList = @()
$nfcList = @()
$safeList = @()

foreach ($item in $items) {
    if      (Test-IsNfd $item.Name) { $nfdList += $item }
    elseif  (Test-IsNfc $item.Name) { $nfcList += $item }
    else    { $safeList += $item }
}

Write-Host "=== Unicode encoding analysis ===" -ForegroundColor Cyan
Write-Host "Directory:  $resolvedPath"
Write-Host "Total:      $($items.Count)"
Write-Host "NFD (macOS): $($nfdList.Count)"
Write-Host "NFC (Win):   $($nfcList.Count)"
Write-Host "Normal:     $($safeList.Count)"

if ($nfdList.Count -eq 0 -and $nfcList.Count -eq 0) {
    Write-Host "`nNo NFD/NFC conflicts found." -ForegroundColor Green
    exit 0
}

# Build duplicate pairs
if ($KeepNfd) {
    # keep NFD: scan NFC files, find matching NFD
    $pairs = @()
    foreach ($nfc in $nfcList) {
        $nfdName = $nfc.Name.Normalize([System.Text.NormalizationForm]::FormD)
        $match = $nfdList | Where-Object { [System.String]::Equals($_.Name, $nfdName, $Ordinal) }
        if ($match) {
            $pairs += [PSCustomObject]@{
                DeleteFile = $nfc
                KeepFile   = $match
                SizeKB     = [math]::Round($nfc.Length / 1KB, 1)
            }
        }
    }
} else {
    # keep NFC (default): scan NFD files, find matching NFC
    $pairs = @()
    foreach ($nfd in $nfdList) {
        $nfcName = $nfd.Name.Normalize([System.Text.NormalizationForm]::FormC)
        $match = $nfcList | Where-Object { [System.String]::Equals($_.Name, $nfcName, $Ordinal) }
        if ($match) {
            $pairs += [PSCustomObject]@{
                DeleteFile = $nfd
                KeepFile   = $match
                SizeKB     = [math]::Round($nfd.Length / 1KB, 1)
            }
        }
    }
}

$keepForm  = if ($KeepNfd) { "NFD" } else { "NFC" }
$deleteForm = if ($KeepNfd) { "NFC" } else { "NFD" }
$totalSizeKB = [math]::Round(($pairs | Measure-Object -Property SizeKB -Sum).Sum, 1)

Write-Host "`n=== Duplicates (keep $keepForm, delete $deleteForm) ===" -ForegroundColor Cyan
Write-Host "Pairs:    $($pairs.Count)"
Write-Host "To free:  ${totalSizeKB} KB"

if ($pairs.Count -eq 0) {
    Write-Host "(No fully-paired NFD/NFC duplicates)" -ForegroundColor Yellow
    exit 0
}

if (-not $Delete) {
    Write-Host "`nFiles to be deleted (dry-run):" -ForegroundColor Yellow
    Write-Host "----------------------------------------"
    foreach ($p in $pairs) {
        Write-Host "  DELETE: $($p.DeleteFile.Name)" -ForegroundColor Red
        Write-Host "  KEEP:   $($p.KeepFile.Name)" -ForegroundColor Green
        Write-Host "  SIZE:   $($p.SizeKB) KB"
        Write-Host ""
    }
    Write-Host "Dry-run complete. Run with -Delete to execute:" -ForegroundColor Yellow
    Write-Host "  .\normalize-filenames.ps1 ""$resolvedPath"" -Delete"
    exit 0
}

# Execute deletion
$deleted = 0
$freedBytes = 0
foreach ($p in $pairs) {
    Remove-Item -LiteralPath $p.DeleteFile.FullName -Force
    Write-Host "Deleted: $($p.DeleteFile.Name)" -ForegroundColor DarkRed
    $deleted++
    $freedBytes += $p.DeleteFile.Length
}
$freedMB = [math]::Round($freedBytes / 1MB, 1)
Write-Host "`nDone: $deleted files removed, ${freedMB} MB freed." -ForegroundColor Green
