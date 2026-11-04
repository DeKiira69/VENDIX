$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:5000/')
$listener.Start()
Write-Host 'Servidor corriendo en http://localhost:5000 (No-Cache)'
$webRoot = 'c:\Users\crist\Desktop\VENDIX\flutter_application_1\build\web'

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = $ctx.Request.Url.LocalPath
    if ($path -eq '/') { $path = '/index.html' }
    $file = Join-Path $webRoot $path.Replace('/', '\')

    # Disable all browser caching so updates are immediate
    $ctx.Response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
    $ctx.Response.Headers.Add('Pragma', 'no-cache')
    $ctx.Response.Headers.Add('Expires', '0')

    if (Test-Path $file) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $ext = [System.IO.Path]::GetExtension($file).ToLower()
        $mime = switch ($ext) {
            '.html'  { 'text/html; charset=utf-8' }
            '.js'    { 'application/javascript; charset=utf-8' }
            '.css'   { 'text/css; charset=utf-8' }
            '.json'  { 'application/json' }
            '.png'   { 'image/png' }
            '.ico'   { 'image/x-icon' }
            '.woff2' { 'font/woff2' }
            '.woff'  { 'font/woff' }
            '.ttf'   { 'font/ttf' }
            '.svg'   { 'image/svg+xml' }
            default  { 'application/octet-stream' }
        }
        $ctx.Response.ContentType = $mime
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $ctx.Response.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
        $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
    }
    $ctx.Response.Close()
}
