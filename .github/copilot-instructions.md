# Copilot Instructions for `vets-api`

## 🔴 NO DUPLICATE COMMENTS - ONE COMMENT PER ISSUE TYPE

**NEVER REPEAT THE SAME FEEDBACK** - Consolidate similar issues into single comments.

Example: ❌ 3 SQL injection comments → ✅ "SQL injection - Lines 42, 67. Use parameterized queries"

## ⚠️ CRITICAL PATTERNS TO FLAG

**Security Issues**
- Missing `before_action :authenticate_user!`
- PII in logs: `"User email: #{params[:email]}"`  
- SQL injection: `"SELECT * FROM users WHERE name = '#{param}'"`
- Hardcoded secrets: `api_key = "sk-123"`
- Mass assignment: `User.create(params[:user])`

**Performance Issues**  
- N+1 queries: `users.map { |u| u.profile.name }` without `.includes`
- Missing timeouts: `Faraday.new(url)` without timeout params
- Blocking operations: `sleep()` in controllers
- Background job needed: Slow external calls in controllers

**Code Quality Issues**
- Wrong error format: `{ message: 'error' }` → use `{ error: { code, message } }`
- Service returning `{ success: true }` → use error envelope  
- Non-idempotent: `Model.create!` → use `find_or_create_by`
- No response validation: `JSON.parse(response.body)` without checks
- Method too long: >5-10 lines → extract smaller methods

**Testing Issues**
- `Flipper.enable/disable` → use `allow(Flipper).to receive(:enabled?).with(:feature)`
- Generic stubs missing `.with(:specific_feature)`

**Migration Issues**
- Mixing indexes with schema changes → separate migration with `algorithm: :concurrently`

## Consolidation Template
```
[Category] Issues Found:
- Line X: [violation]  
- Line Y: [violation]
[Fix recommendation]
```

## Context
Rails API serving veterans via VA.gov. Security and performance critical.