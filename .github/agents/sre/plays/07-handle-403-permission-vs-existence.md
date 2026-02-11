# Play 07: Handle 403 Authorization Errors (Permission vs Existence)

## Context
Returning 403 for unauthorized access tells an attacker "this claim exists but you cannot see it," whereas 404 would reveal nothing, so the distinction enables enumeration attacks. An attacker looping through IDs sees 404, 404, 403, 404, and the 403 leaks which claim ID is valid. When an expired token returns 403 instead of 401, the client does not know to refresh its token and the user gets stuck. A validation error that returns 403 instead of 422 gives the client no field-level errors to fix, and the wrong team investigates.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`

## Investigation Steps
1. Read the full controller action to understand the resource type and access pattern.
2. Determine whether the resource's existence should be hidden from unauthorized users. Claims, prescriptions, and health records should be hidden. Admin endpoints and public features with restricted access should not.
3. Check whether the method has separate code paths for "not found" and "not authorized" that return different status codes (enumeration risk).
4. Verify whether the 403 is actually an authentication issue (expired token, missing credentials) that should be 401, or a validation issue that should be 422.
5. Check if `meta.required_permission` is included in 403 responses.

## Severity Assessment
- **CRITICAL**: Controller returns both 403 and 404 for the same resource type, enabling enumeration of veteran claims, health records, or prescriptions
- **CRITICAL**: 403 returned for expired or missing authentication tokens instead of 401
- **HIGH**: 403 returned for validation errors instead of 422
- **HIGH**: 403 response missing meta.required_permission, providing no guidance for remediation
- **MEDIUM**: 403 used for resource where existence is already public knowledge

## Golden Patterns

### Do
Return 404 for both "not found" and "not authorized" on private resources to prevent enumeration:
```ruby
def show
  claim = Claim.find_by(id: params[:id])

  unless claim && current_user.can_access?(claim)
    raise Common::Exceptions::RecordNotFound.new(params[:id])
  end

  render json: claim
end
```

Use `find_by` + nil check instead of `find` + rescue `RecordNotFound`. Include `meta.required_permission` in 403 responses.

### Don't
Never return 403 for expired tokens -- use 401 (authentication failure). Never return 403 for missing resources -- use 404 (not found). Never return 403 for validation failures -- use 422 (unprocessable entity). Never split 403/404 on the same resource type -- enables enumeration attacks:
```ruby
# BAD -- attacker can distinguish "exists" from "doesn't exist"
def show
  claim = Claim.find(params[:id])
  unless current_user.can_access?(claim)
    raise Common::Exceptions::Forbidden.new(detail: "Access denied")  # 403 = exists!
  end
  render json: claim
rescue ActiveRecord::RecordNotFound
  raise Common::Exceptions::RecordNotFound.new(params[:id])  # 404 = doesn't exist
end
```

## Anti-Patterns

### Information Leakage via Split Status Codes
**Anti-pattern:**
```ruby
def show
  claim = Claim.find(params[:id])

  unless current_user.can_access?(claim)
    raise Common::Exceptions::Forbidden.new(detail: "Access denied")
  end

  render json: claim
rescue ActiveRecord::RecordNotFound
  raise Common::Exceptions::RecordNotFound.new(params[:id])
end
```
**Problem:** Attacker can enumerate valid claim IDs by observing 403 vs 404. The split response codes leak resource existence. An attacker looping through IDs sees 404, 404, 403, 404 -- the 403 reveals which claim IDs are valid.

**Corrected:**
```ruby
def show
  claim = Claim.find_by(id: params[:id])

  # Return 404 for both "doesn't exist" AND "exists but you can't access"
  unless claim && current_user.can_access?(claim)
    raise Common::Exceptions::RecordNotFound.new(params[:id])
  end

  render json: claim
end
```

### Wrong Status for Expired Token
**Anti-pattern:**
```ruby
def show
  raise Common::Exceptions::Forbidden.new(
    detail: "Access denied"
  ) unless current_user.token_valid?

  render json: resource
end
```
**Problem:** Client does not know to refresh its token. User gets stuck. Wrong team investigates authorization when the issue is authentication.

**Corrected:**
```ruby
def show
  unless current_user.token_valid?
    raise Common::Exceptions::Unauthorized.new(
      detail: "Session expired. Please sign in again."
    )
  end

  render json: resource
end
```

## Finding Template
**Handle 403 Authorization Errors (Permission vs Existence)** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** {{why_it_matters_summary}} (e.g., split 403/404 responses
allow attackers to enumerate valid resource IDs by observing which status code
is returned for each ID).

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] Correct status code for failure type (401/403/404/422)
- [ ] No split 403/404 on same resource (use unified 404 for hidden resources)
- [ ] `meta.required_permission` included in 403 responses
- [ ] `find_by` used instead of `find` for unified 404 pattern

[Play: Handle 403 Authorization Errors](plays/handle-403-permission-vs-existence.md)

## Verify Commands
- `grep -On 'Forbidden.*RecordNotFound|RecordNotFound.*Forbidden' {{file_path}}` -- No Forbidden followed by RecordNotFound in same method
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- handle-401-token-ownership (complementary)
- dont-leak-pii (complementary)
