# Output Format

```markdown
# OWASP Top 10:2025 Audit Report
**Scope:** [files/directories reviewed]
**Not reviewed:** [anything explicitly out of scope — infra, CI config, third-party services, etc.]
**Findings:** Critical: X | High: X | Medium: X | Low: X

---

## CRITICAL

### [VULN-001] [Finding title]
- **Category:** [A0X:2025 - Name]
- **Severity:** Critical
- **File:** `path/to/file.py:42`
- **Vulnerable code:**
  ```python
  # exact snippet from the file
  ```

- **How it's exploited:** [1-2 sentences, concrete attacker steps]
- **Fix:**

  ```python
  # corrected code
  ```

---

## HIGH

[same structure]

## MEDIUM

[same structure]

## LOW

[same structure]

---

## Clean Categories

✅ [A0X:2025 - Name] — no issues found. [one line on what was checked]

## Worth Investigating Further

[Leads from recon or partial review that need more context/access to confirm — not counted in the
Findings tally above.]

---

## Summary Table

| ID | Severity | Category | File | Issue |
|----|----------|----------|------|-------|
| VULN-001 | Critical | A05:2025 | app.py:42 | SQL injection via string concat |
...

## Remediation Priority

1. [Most urgent — usually Critical + easiest to exploit]
2. ...

---

**Limitations:** This is a manual code-level review, not a full pentest. It doesn't cover runtime/DAST
issues, business-logic flaws that need domain context beyond what's in the code, or infra it didn't have
access to. Treat Critical/High findings as immediately actionable; treat the rest as a hardening backlog.

```
