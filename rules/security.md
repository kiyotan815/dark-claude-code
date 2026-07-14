# Security Guidelines

## Mandatory Checks Before ANY Commit

- [ ] No hardcoded secrets — use environment variables and fail fast if unset
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitized HTML)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on endpoints
- [ ] Error messages don't leak sensitive data

## Security Response Protocol

If a security issue is found:
1. STOP immediately and use the **security-reviewer** agent
2. Fix CRITICAL issues before continuing
3. Rotate any exposed secrets
4. Review the codebase for similar issues
