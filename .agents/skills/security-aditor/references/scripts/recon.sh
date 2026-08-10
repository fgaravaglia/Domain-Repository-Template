#!/usr/bin/env bash
# OWASP Top 10:2025 recon — grep-based leads, NOT confirmed findings.
# Usage: ./recon.sh <path-to-codebase>
# Every hit needs manual read-through before it goes in a report.

set -uo pipefail
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Usage: $0 <path-to-codebase>"
  exit 1
fi

EXCLUDE_DIRS='(node_modules|\.git|dist|build|vendor|\.venv|venv|__pycache__|target|bin|obj)'

section () { echo; echo "=== $1 ==="; }
hits () { grep -RInE --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
                     --exclude-dir=build --exclude-dir=vendor --exclude-dir=.venv \
                     --exclude-dir=venv --exclude-dir=__pycache__ --exclude-dir=target \
                     --exclude-dir=bin --exclude-dir=obj "$1" "$TARGET" 2>/dev/null | head -50; }

section "A05:2025 Injection — SQL string building"
hits 'SELECT .* \+ |f"(SELECT|INSERT|UPDATE|DELETE)|`(SELECT|INSERT|UPDATE|DELETE).*\$\{|"(SELECT|INSERT|UPDATE|DELETE).*"\s*\+'

section "A05:2025 Injection — command exec / eval"
hits '\beval\(|\bexec\(|os\.system\(|subprocess\.(call|run|Popen)\([^)]*shell\s*=\s*True|child_process\.(exec|execSync)\('

section "A05:2025 Injection — unsafe HTML rendering"
hits 'dangerouslySetInnerHTML|innerHTML\s*=|v-html='

section "A04:2025 Cryptographic Failures — weak hashing"
hits '\bmd5\(|\bsha1\(|hashlib\.md5|hashlib\.sha1|Md5\.Create|MessageDigest\.getInstance\("MD5"\)|MessageDigest\.getInstance\("SHA-1"\)'

section "A04:2025 Cryptographic Failures — hardcoded secrets"
hits '(api[_-]?key|secret|password|private[_-]?key|token)\s*[:=]\s*["'\''][A-Za-z0-9_\-]{8,}["'\'']'

section "A04:2025 Cryptographic Failures — TLS verification disabled"
hits 'verify\s*=\s*False|rejectUnauthorized:\s*false|NODE_TLS_REJECT_UNAUTHORIZED|ServerCertificateCustomValidationCallback|InsecureSkipVerify:\s*true'

section "A04:2025 Cryptographic Failures — weak randomness near auth-ish names"
hits 'Math\.random\(\)|random\.random\(\)' | grep -iE 'token|session|password|otp|reset' || echo "(no obviously auth-related weak-random hits — re-check manually, grep pairing is approximate)"

section "A07:2025 Authentication Failures — JWT decode without verify"
hits 'jwt\.decode\([^,]*\)\s*;?\s*$|jwt_decode\(|alg.*none'

section "A08:2025 Software/Data Integrity — unsafe deserialization"
hits 'pickle\.loads|yaml\.load\((?!.*Loader=yaml\.SafeLoader)|unserialize\(|ObjectInputStream|readObject\(\)'

section "A02:2025 Security Misconfiguration — debug mode / verbose errors"
hits 'DEBUG\s*=\s*True|app\.debug\s*=\s*true|NODE_ENV.*development|ASPNETCORE_ENVIRONMENT.*Development'

section "A02:2025 Security Misconfiguration — permissive CORS"
hits "Access-Control-Allow-Origin.*\*|cors\(\{\s*origin:\s*.?\*"

section "A01:2025 Broken Access Control — SSRF-shaped fetch of user-controlled URL"
hits 'requests\.get\(.*request\.|fetch\(.*req\.(query|body|params)|HttpClient.*Get.*req\.'

section "A03:2025 Software Supply Chain — unpinned CI actions / floating deps"
hits 'uses:\s*[^@]+@(main|master|latest)'
echo "--- dependency manifests without lockfiles (check manually) ---"
find "$TARGET" -maxdepth 3 -iname "package.json" -o -iname "requirements.txt" 2>/dev/null | \
  grep -Ev "$EXCLUDE_DIRS" | head -20

section "A10:2025 Mishandling of Exceptional Conditions — empty/swallowed catch blocks"
hits 'catch\s*\([^)]*\)\s*\{\s*\}|except\s*:\s*pass\b|except\s+Exception\s*:\s*pass\b'

echo
echo "=== Recon complete ==="
echo "These are LEADS only. Read the surrounding code for each hit before reporting a finding —"
echo "grep has no idea about context, sanitization happening elsewhere, or intentional test fixtures."