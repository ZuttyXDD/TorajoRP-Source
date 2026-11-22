$ErrorActionPreference = 'Stop'

$projectFile = $env:TORAJORP_PROJECT_XML
if (-not $projectFile -or -not (Test-Path -LiteralPath $projectFile)) {
    Write-Host '[AVISO] project.xml nao encontrado.'
    exit 0
}

$raw = Get-Content -LiteralPath $projectFile -Raw
$matches = [regex]::Matches(
    $raw,
    '(?is)<haxelib\b[^>]*\bname\s*=\s*["'']([^"'']+)["'']'
)

$libs = @(
    $matches |
    ForEach-Object { $_.Groups[1].Value.Trim() } |
    Where-Object { $_ } |
    Sort-Object -Unique
)

if ($libs.Count -eq 0) {
    Write-Host '[AVISO] Nenhuma dependencia haxelib encontrada no project.xml.'
    exit 0
}

foreach ($lib in $libs) {
    $installed = (& haxelib list 2>$null) -join "`n"
    if ($installed -match ('(?m)^' + [regex]::Escape($lib) + ':')) {
        Write-Host "[OK] $lib ja esta instalado."
    }
    else {
        Write-Host "[INSTALANDO] $lib..."
        & haxelib install $lib
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Falha ao instalar $lib"
            exit 1
        }
    }
}

exit 0
