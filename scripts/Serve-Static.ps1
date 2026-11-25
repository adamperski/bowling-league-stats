<#
    Minimal static file server (no Python/Node on this machine) - just for
    previewing dashboard.html locally in the browser tool during development.
    Not part of the deployed site (GitHub Pages serves docs/ directly).
#>
param([int]$Port = 8734)
$root = Split-Path -Parent $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/"
$mime = @{ '.html'='text/html'; '.js'='application/javascript'; '.css'='text/css'; '.json'='application/json'; '.svg'='image/svg+xml' }
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $reqPath = $ctx.Request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($reqPath)) { $reqPath = 'dashboard.html' }
        $filePath = Join-Path $root $reqPath
        try {
            if (Test-Path $filePath -PathType Leaf) {
                $ext = [IO.Path]::GetExtension($filePath)
                $ctx.Response.ContentType = if ($mime[$ext]) { $mime[$ext] } else { 'application/octet-stream' }
                $bytes = [IO.File]::ReadAllBytes($filePath)
                $ctx.Response.ContentLength64 = $bytes.Length
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $ctx.Response.StatusCode = 404
            }
        } catch {
            Write-Host "Request error: $_"
        } finally {
            $ctx.Response.Close()
        }
    }
} finally {
    $listener.Stop()
}
