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

## Supabase / Vercel Projects

Most breaches on this stack are misconfiguration, not code: RLS disabled,
`using (true)` policies, `service_role` keys on the client, public buckets,
unauthenticated cron endpoints, unprotected preview deployments. Run
`/dcc:security-audit` (the `dcc:supabase-vercel-audit` skill) before launch,
after schema changes that add tables or policies, and quarterly.

## Security Response Protocol

If a security issue is found:
1. STOP immediately and use the **dcc:security-reviewer** agent
2. Fix CRITICAL issues before continuing
3. Rotate any exposed secrets
4. Review the codebase for similar issues
