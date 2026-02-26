---
id: handle-403-permission
title: Handle 403 Authorization Errors (Permission vs Existence)
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    Returning 403 for unauthorized access tells an attacker "this claim
    exists but you cannot see it," whereas 404 would reveal nothing, so
    the distinction enables enumeration attacks. An attacker looping
    through IDs sees 404, 404, 403, 404, and the 403 leaks which claim
    ID is valid. When an expired token returns 403 instead of 401, the
    client does not know to refresh its token and the user gets stuck. A
    validation error that returns 403 instead of 422 gives the client no
    field-level errors to fix, and the wrong team investigates.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="handle-401-token-ownership" relationship="complementary" />
    <play id="dont-leak-pii" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Use 403 only for authenticated users who lack permission to
      access a resource or perform an action.
    </rule>
    <rule enforcement="must_not">
      Never return 403 for expired or missing tokens — use 401
      (authentication failure).
    </rule>
    <rule enforcement="must_not">
      Never return 403 for non-existent resources — use 404 (not
      found).
    </rule>
    <rule enforcement="must_not">
      Never return 403 for validation failures — use 422
      (unprocessable entity).
    </rule>
    <rule enforcement="must">
      Return 404 instead of 403 when the resource's existence should
      be hidden from unauthorized users to prevent enumeration
      attacks.
    </rule>
    <rule enforcement="should">
      Include `meta.required_permission` in 403 responses to guide
      clients and administrators.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full controller action to understand the resource type and access pattern.</step>
    <step>Determine whether the resource's existence should be hidden from unauthorized users. Claims, prescriptions, and health records should be hidden. Admin endpoints and public features with restricted access should not.</step>
    <step>Check whether the method has separate code paths for "not found" and "not authorized" that return different status codes (enumeration risk).</step>
    <step>Verify whether the 403 is actually an authentication issue (expired token, missing credentials) that should be 401, or a validation issue that should be 422.</step>
    <step>Check if `meta.required_permission` is included in 403 responses.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>controller returns both 403 and 404 for the same resource
type, enabling enumeration of veteran claims, health records,
or prescriptions</critical>
    <critical>403 returned for expired or missing authentication tokens
instead of 401</critical>
    <high>403 returned for validation errors instead of 422</high>
    <high>403 response missing meta.required_permission, providing no
guidance for remediation</high>
    <medium>403 used for resource where existence is already public
knowledge</medium>
  </severity_assessment>

  <pr_comment_template>
    **Handle 403 Authorization Errors (Permission vs Existence)** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

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

    [Play: Handle 403 Authorization Errors](07-handle-403-permission-vs-existence.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Return 404 for both "not found" and "not authorized" on private resources — prevents enumeration
- Use `find_by` + nil check instead of `find` + rescue `RecordNotFound`
- Include `meta.required_permission` in 403 responses

### Don't

- Return 403 for expired tokens — use 401 (authentication failure)
- Return 403 for missing resources — use 404 (not found)
- Return 403 for validation failures — use 422 (unprocessable entity)
- Split 403/404 on the same resource type — enables enumeration attacks

## Anti-Patterns

### Information Leakage via Split Status Codes

```ruby
def show
  claim = Claim.find(params[:id])

  unless current_user.can_access?(claim)
    # Returns 403 — tells attacker claim ID exists!
    raise Common::Exceptions::Forbidden.new(detail: "Access denied")
  end

  render json: claim
rescue ActiveRecord::RecordNotFound
  # Returns 404 — tells attacker claim ID doesn't exist
  raise Common::Exceptions::RecordNotFound.new(params[:id])
end
```

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

```ruby
def show
  # Expired token returns 403 instead of 401
  raise Common::Exceptions::Forbidden.new(
    detail: "Access denied"
  ) unless current_user.token_valid?

  render json: resource
end
```

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
