# Copilot Instructions for `vets-api`

## 🔴 NO DUPLICATE COMMENTS - ONE COMMENT PER ISSUE TYPE

**NEVER REPEAT THE SAME FEEDBACK** - Consolidate similar issues into single comments.

Example: ❌ 3 SQL injection comments → ✅ "SQL injection - Lines 42, 67. Use parameterized queries"

## ⚠️ CRITICAL PATTERNS TO FLAG

**ALWAYS FLAG THESE EXACT CODE PATTERNS:**
- `Faraday.new('https://external-api.example.com')` → add timeout
- `ExampleRecord.create!(name: params[:name], value: params[:value])` → not idempotent
- `render json: { message: 'Something went wrong' }` → wrong error format
- `Flipper.enable(:test_feature)` → never use in tests
- Methods with 10+ lines → too long (Sandi Metz)

## ⚠️ VIOLATION CATEGORIES

**Security Issues**
- Missing `before_action :authenticate_user!`
- PII in logs: `"User email: #{params[:email]}"`  
- SQL injection: `"SELECT * FROM users WHERE name = '#{param}'"`
- Hardcoded secrets: `api_key = "sk-123"`
- Mass assignment: `User.create(params[:user])`

**Performance Issues**  
- N+1 queries: `users.map { |u| u.profile.name }` without `.includes`
- Missing HTTP timeouts: `Faraday.new('https://api.example.com')` without `timeout:` params
- Missing retries: `@client.get("/path")` without retry logic
- Blocking operations: `sleep()` in controllers
- Background job needed: Slow external calls in controllers

**Code Quality Issues**
- Wrong error format: `render json: { message: 'Something went wrong' }` → use `{ error: { code, message } }`
- Service returning `{ success: true }` → use error envelope  
- Non-idempotent creates: `ExampleRecord.create!(name: params[:name])` → use `find_or_create_by`
- No response validation: `JSON.parse(response.body)` without checks
- Method too long: Methods with >10 lines of code → extract smaller methods (Sandi Metz rules)

**Testing Issues**
- `Flipper.enable(:test_feature)` in tests → use `allow(Flipper).to receive(:enabled?).with(:feature)`
- `Flipper.disable(:test_feature)` in tests → use stubbing instead
- Generic stubs: `allow(Flipper).to receive(:enabled?).and_return(true)` missing `.with(:specific_feature)`

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