# OWASP Top 10:2025 recon — pattern-based leads, NOT confirmed findings.
# Usage: .\recon.ps1 -Target <path-to-codebase>
# Every hit needs manual read-through before it goes in a report.
# Native PowerShell — no WSL/Git Bash required.

param(
    [Parameter(Mandatory = $false)]
    [string]$Target = "."
)

if (-not (Test-Path $Target -PathType Container)) {
    Write-Host "Usage: .\recon.ps1 -Target <path-to-codebase>"
    exit 1
}

$ExcludeDirs = @('node_modules', '.git', 'dist', 'build', 'vendor', '.venv', 'venv',
    '__pycache__', 'target', 'bin', 'obj', 'packages')

function Get-ScanFiles {
    param([string]$Path)
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $full = $_.FullName
        -not ($ExcludeDirs | Where-Object { $full -match [regex]::Escape("\$_\") })
    }
}

function Show-Section { param([string]$Title) Write-Host "`n=== $Title ===" -ForegroundColor Cyan }

function Show-Hits {
    param([string]$Pattern, [System.Collections.Generic.List[System.IO.FileInfo]]$Files)
    $count = 0
    foreach ($f in $Files) {
        $matches = Select-String -Path $f.FullName -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
        foreach ($m in $matches) {
            "$($f.FullName):$($m.LineNumber): $($m.Line.Trim())"
            $count++
            if ($count -ge 50) { return }
        }
    }
}

Write-Host "Indexing files under $Target ..." -ForegroundColor Yellow
$files = [System.Collections.Generic.List[System.IO.FileInfo]](Get-ScanFiles -Path $Target)
Write-Host "$($files.Count) files indexed."

Show-Section "A05:2025 Injection - SQL string building"
Show-Hits -Pattern 'SELECT .*\+ |f"(SELECT|INSERT|UPDATE|DELETE)|`(SELECT|INSERT|UPDATE|DELETE).*\$\{|"(SELECT|INSERT|UPDATE|DELETE).*"\s*\+' -Files $files

Show-Section "A05:2025 Injection - command exec / eval"
Show-Hits -Pattern '\beval\(|\bexec\(|os\.system\(|shell\s*=\s*True|child_process\.(exec|execSync)\(|Process\.Start\(' -Files $files

Show-Section "A05:2025 Injection - unsafe HTML rendering"
Show-Hits -Pattern 'dangerouslySetInnerHTML|innerHTML\s*=|v-html=|Html\.Raw\(' -Files $files

Show-Section "A04:2025 Cryptographic Failures - weak hashing"
Show-Hits -Pattern '\bmd5\(|\bsha1\(|hashlib\.md5|hashlib\.sha1|MD5\.HashData|SHA1\.HashData|MessageDigest\.getInstance\("MD5"\)|MessageDigest\.getInstance\("SHA-1"\)' -Files $files

Show-Section "A04:2025 Cryptographic Failures - hardcoded secrets"
Show-Hits -Pattern '(ApiKey|api[_-]?key|secret|password|pwd|private[_-]?key|token)\s*[:=]\s*"[A-Za-z0-9_\-]{8,}"' -Files $files

Show-Section "A04:2025 Cryptographic Failures - TLS verification disabled"
Show-Hits -Pattern 'verify\s*=\s*False|rejectUnauthorized:\s*false|ServerCertificateCustomValidationCallback|InsecureSkipVerify:\s*true|ServicePointManager\.ServerCertificateValidationCallback' -Files $files

Show-Section "A07:2025 Authentication Failures - JWT decode without verify / weak config"
Show-Hits -Pattern 'jwt\.decode\(|jwt_decode\(|ValidateLifetime\s*=\s*false|ValidateIssuerSigningKey\s*=\s*false' -Files $files

Show-Section "A08:2025 Software/Data Integrity - unsafe deserialization"
Show-Hits -Pattern 'pickle\.loads|BinaryFormatter|TypeNameHandling\.All|ObjectInputStream|unserialize\(' -Files $files

Show-Section "A02:2025 Security Misconfiguration - debug mode / verbose errors"
Show-Hits -Pattern 'DEBUG\s*=\s*True|app\.debug\s*=\s*true|UseDeveloperExceptionPage|ASPNETCORE_ENVIRONMENT.*Development' -Files $files

Show-Section "A02:2025 Security Misconfiguration - permissive CORS"
Show-Hits -Pattern 'Access-Control-Allow-Origin.*\*|AllowAnyOrigin\(\)|origin:\s*.\*' -Files $files

Show-Section "A01:2025 Broken Access Control - SSRF-shaped fetch of user-controlled URL"
Show-Hits -Pattern 'requests\.get\(.*request\.|fetch\(.*req\.(query|body|params)|HttpClient.*Get.*userProvidedUrl|_httpClient\.GetAsync\(.*[Uu]rl\)' -Files $files

Show-Section "A03:2025 Software Supply Chain - unpinned CI actions / floating deps"
Show-Hits -Pattern 'uses:\s*[^@]+@(main|master|latest)' -Files $files
Write-Host "--- dependency manifests found (check lockfiles manually) ---"
Get-ChildItem -Path $Target -Recurse -File -Include "package.json", "*.csproj", "packages.config" -ErrorAction SilentlyContinue |
Where-Object { $full = $_.FullName; -not ($ExcludeDirs | Where-Object { $full -match [regex]::Escape("\$_\") }) } |
Select-Object -First 20 -ExpandProperty FullName

Show-Section "A10:2025 Mishandling of Exceptional Conditions - empty/swallowed catch blocks"
Show-Hits -Pattern 'catch\s*\([^)]*\)\s*\{\s*\}|catch\s*\{\s*\}|except\s*:\s*pass\b|except\s+Exception\s*:\s*pass\b' -Files $files

Write-Host "`n=== Recon complete ===" -ForegroundColor Green
Write-Host "These are LEADS only. Read the surrounding code for each hit before reporting a finding -"
Write-Host "regex matching has no idea about context, sanitization happening elsewhere, or test fixtures."