# Copilot Instructions for `vets-api`

## 🔴 NO DUPLICATE COMMENTS - CRITICAL RULE

**ONE COMMENT PER ISSUE TYPE**
- Find same issue multiple times? Make ONE consolidated comment
- List ALL lines in that single comment
- NEVER repeat the same feedback

**Examples:**
❌ Bad: 3 comments about SQL injection
✅ Good: "SQL injection - Lines 42, 67. Use parameterized queries"

## Priority Issues

**Security (Critical)**
- Missing authentication
- PII in logs (email, SSN) 
- SQL injection
- Hardcoded secrets

**Performance**
- N+1 queries (missing includes)
- Missing HTTP timeouts
- Blocking operations in controllers

**Quality**
- Wrong error format - use `{ error: { code, message } }`
- Non-idempotent creates
- Service methods returning `{ success: true }`

**Testing**
- No `Flipper.enable/disable` - use stubs with `.with(:feature)`

**Migrations** 
- Index changes need separate migration with `algorithm: :concurrently`

## Consolidation Template
```
[Category] Issues:
- Line X: [specific issue]
- Line Y: [specific issue]
[Fix recommendation]
```

## Context
- API serves veterans via VA.gov
- PII/PHI protection paramount
- External services fail often - use timeouts
- Security > functionality > style