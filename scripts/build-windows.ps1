param([switch]$ReuseEngine)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    $python = Join-Path $project '.tools\python\Scripts\python.exe'
    if (!(Test-Path $python)) { $python = 'python' }
    if (!$ReuseEngine) {
        $target = 'x86_64-pc-windows-msvc'
        $toolchain = 'stable'
        if (Test-Path '.tools\cargo\bin\cargo.exe') {
            $env:CARGO_HOME = Join-Path $project '.tools\cargo'
            $env:RUSTUP_HOME = Join-Path $project '.tools\rustup'
            $env:PATH = "$env:CARGO_HOME\bin;$project\.tools\llvm-mingw-20261020-ucrt-x86_64\bin;$env:PATH"
            $toolchain = 'stable-x86_64-pc-windows-gnu'
            $target = 'x86_64-pc-windows-gnullvm'
        }
        cargo "+$toolchain" test --locked --release --lib --target $target
        if ($LASTEXITCODE) { throw 'Rust tests failed.' }
        cargo "+$toolchain" build --locked --release --bin directside-engine --target $target
        if ($LASTEXITCODE) { throw 'Engine build failed.' }
        New-Item -ItemType Directory bin -Force | Out-Null
        Copy-Item "target\$target\release\directside-engine.exe" bin\directside-engine.exe
        if ($target -eq 'x86_64-pc-windows-gnullvm') {
            Copy-Item '.tools\llvm-mingw-20261020-ucrt-x86_64\bin\libunwind.dll' bin\libunwind.dll
        }
    }
    & $python -m pip install -r ui/requirements.txt
    if ($LASTEXITCODE) { throw 'Dependencies failed.' }
    & $python -m unittest discover -s tests
    if ($LASTEXITCODE) { throw 'UI tests failed.' }
    # Local-only Apple runtime for this private desktop package. Never uploaded to Git.
    $appleRuntime = Join-Path ${env:ProgramFiles} 'iTunes\CoreADI64.dll'
    if (!(Test-Path 'bin\apple\CoreADI64.dll')) {
        if (!(Test-Path $appleRuntime)) { throw 'Local Apple CoreADI runtime unavailable; no remote fallback is allowed.' }
        New-Item -ItemType Directory -Path bin\apple -Force | Out-Null
        Copy-Item -LiteralPath $appleRuntime -Destination bin\apple\CoreADI64.dll
    }
    $originalPath = $env:PATH
    try {
        $pythonDirectory = Split-Path (& $python -c 'import sys; print(sys.executable)') -Parent
        $env:PATH = "$pythonDirectory;$env:SystemRoot\System32;$env:SystemRoot"
        & $python -m PyInstaller --noconfirm --clean --distpath dist --workpath build\pyinstaller packaging\DirectSide.spec
        if ($LASTEXITCODE) { throw 'Windows packaging failed.' }
        $report = Join-Path $project 'build\smoke-test.json'
        if (Test-Path $report) { Remove-Item -LiteralPath $report }
        $application = Start-Process -FilePath (Join-Path $project 'dist\DirectSide.exe') -ArgumentList ('--smoke-test "{0}"' -f $report) -WindowStyle Hidden -PassThru
        if (!$application.WaitForExit(30000)) { $application.Kill(); throw 'Packaged application startup timed out.' }
        if (!(Test-Path $report)) { throw 'Packaged application failed before producing a startup report.' }
        $result = Get-Content $report -Raw | ConvertFrom-Json
        if (!$result.passed) { throw 'Packaged application startup check failed.' }
        Write-Host 'Packaged Qt, QML, icon and signing engine startup: PASS'
    } finally { $env:PATH = $originalPath }
} finally { Pop-Location }
