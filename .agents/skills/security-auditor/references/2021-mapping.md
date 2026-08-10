# OWASP Top 10: 2021 → 2025 Mapping

Use only if the user specifically needs the 2021 taxonomy (e.g. a client contract or compliance
mandate still references it). Default to 2025 otherwise.

| 2021 | 2025 |
| --- | --- |
| A01:2021 - Broken Access Control | A01:2025 - Broken Access Control |
| A02:2021 - Cryptographic Failures | A04:2025 - Cryptographic Failures |
| A03:2021 - Injection | A05:2025 - Injection |
| A04:2021 - Insecure Design | A06:2025 - Insecure Design |
| A05:2021 - Security Misconfiguration | A02:2025 - Security Misconfiguration |
| A06:2021 - Vulnerable and Outdated Components | A03:2025 - Software Supply Chain Failures (expanded scope) |
| A07:2021 - Identification and Authentication Failures | A07:2025 - Authentication Failures (renamed) |
| A08:2021 - Software and Data Integrity Failures | A08:2025 - Software or Data Integrity Failures |
| A09:2021 - Security Logging and Monitoring Failures | A09:2025 - Security Logging & Alerting Failures (renamed) |
| A10:2021 - Server-Side Request Forgery (SSRF) | Folded into A01:2025 - Broken Access Control |
| *(no 2021 equivalent)* | A10:2025 - Mishandling of Exceptional Conditions (new) |

Note: "Sensitive Data Exposure" was the *2017* name for what became "Cryptographic Failures" in 2021 —
if you see that even older term in a legacy prompt, it maps the same way, to A04:2025.
