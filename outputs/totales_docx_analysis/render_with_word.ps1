param(
    [Parameter(Mandatory = $true)][string]$InputDocx,
    [Parameter(Mandatory = $true)][string]$OutputPdf
)

$word = $null
$document = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $missing = [System.Type]::Missing
    $arguments = [object[]]@(
        $InputDocx, $false, $true, $false,
        $missing, $missing, $false, $missing,
        $missing, $missing, $missing, $false,
        $true, $missing, $true, $missing
    )
    $document = $word.Documents.GetType().InvokeMember(
        'Open',
        [System.Reflection.BindingFlags]::InvokeMethod,
        $null,
        $word.Documents,
        $arguments
    )
    $document.ExportAsFixedFormat($OutputPdf, 17)
} finally {
    if ($null -ne $document) {
        $document.Close($false)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
    }
    if ($null -ne $word) {
        $word.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
