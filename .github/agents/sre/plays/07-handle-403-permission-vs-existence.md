---
id: handle-403-permission
title: Handle 403 Authorization Errors (Permission vs Existence)
version: 1
severity: CRITICAL
category: security
tags:
- 403
- authorization
- enumeration
- permission
- resource-existence
language: ruby
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

  <retrieval_triggers>
    <trigger>403 forbidden leaks resource existence to attacker</trigger>
    <trigger>should return 404 instead of 403 to prevent enumeration</trigger>
    <trigger>expired token returns 403 instead of 401</trigger>
    <trigger>validation error returns 403 instead of 422</trigger>
    <trigger>authorization vs authentication error handling</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="forbidden_with_record_not_found" confidence="high">
      <signature>raise.*Forbidden.*\n.*RecordNotFound|RecordNotFound.*\n.*Forbidden</signature>
      <description>
        A `raise Forbidden` followed by `RecordNotFound` handling (or
        vice versa) in the same method. When a method returns 403 for
        unauthorized access and 404 for missing resources, an attacker
        can enumerate valid resource IDs by observing which status
        code is returned. The difference between 403 and 404 leaks
        resource existence.
      </description>
      <example>raise Common::Exceptions::Forbidden.new(detail: "Access denied")` followed by `rescue ActiveRecord::RecordNotFound</example>
      <example>Method with both `Forbidden` and `RecordNotFound` in separate branches</example>
    </pattern>
    <pattern name="forbidden_access_denied" confidence="medium">
      <signature>Forbidden\.new.*detail.*access denied</signature>
      <description>
        A `Forbidden.new` with an "access denied" detail message.
        Medium confidence because 403 is sometimes correct (user can
        see resource exists but lacks permission). Requires
        investigation to determine whether the resource's existence
        should be hidden from unauthorized users (in which case 404 is
        the secure choice).
      </description>
      <example>raise Common::Exceptions::Forbidden.new(detail: "Access denied")</example>
      <example>Forbidden.new(detail: "access denied to this resource")</example>
    </pattern>
    <pattern name="rescue_not_found_raises_forbidden" confidence="high">
      <signature>rescue\s+ActiveRecord::RecordNotFound.*\n.*Forbidden</signature>
      <description>
        A rescue block for `ActiveRecord::RecordNotFound` that raises
        `Forbidden`. This inverts the correct behavior: when a record
        is not found, it should return 404. Returning 403 for a not-
        found resource tells the attacker the resource ID format is
        valid but they lack access, which is misleading and leaks
        implementation details.
      </description>
      <example>rescue ActiveRecord::RecordNotFound` followed by `raise Common::Exceptions::Forbidden</example>
    </pattern>
    <heuristic>
      A controller action that uses `Claim.find(params[:id])`
      followed by a permission check raising 403, with a separate
      `rescue ActiveRecord::RecordNotFound` raising 404, is a strong
      signal of information leakage. The split response codes allow
      attackers to enumerate valid claim IDs.
    </heuristic>
    <heuristic>
      Any controller action that returns different status codes for
      "not found" vs "not authorized" on the same resource type
      should be evaluated for whether the resource existence should
      be hidden from unauthorized users.
    </heuristic>
    <false_positive>
      Returning 403 for resources where existence is already public
      knowledge or discoverable through other means (e.g., admin
      panel features visible in navigation but not accessible). When
      the user can already see the resource exists, 403 is
      appropriate because hiding existence provides no security
      benefit.
    </false_positive>
    <false_positive>
      Authorization middleware or before_action filters that return
      403 for role-based access control on entire endpoints (e.g.,
      admin-only routes). These do not leak individual resource
      existence because the 403 applies to the endpoint itself, not
      a specific resource ID.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a 403/404 enumeration vulnerability, provide
    the unified 404 pattern using `find_by` instead of `find`.
    When you detect a misused 403, provide the correct status code.
  </default_to_action>

  <verify>
    <command description="No Forbidden followed by RecordNotFound in same method">
      grep -On 'Forbidden.*RecordNotFound|RecordNotFound.*Forbidden' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Handle 403 Authorization Errors](plays/handle-403-permission-vs-existence.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Information Leakage via Split Status Codes" file="inline-example" />
    <source name="Wrong Status for Expired Token" file="inline-example" />
  </anti_pattern_sources>

</agent_play>
-->

# Handle 403 Authorization Errors (Permission vs Existence)

Use 403 only when an authenticated user lacks permission. Never use 403 for expired tokens (that's 401), missing resources (that's 404), or validation failures (that's 422). When the resource should be hidden, return 404 for both "not found" and "not authorized."

> [!CAUTION]
> Returning 403 for unauthorized access and 404 for missing resources on the same endpoint leaks resource existence to attackers.

## Why It Matters

When you return 403 for unauthorized access and 404 for missing resources, an attacker looping through IDs sees 404, 404, 403, 404 — the 403 leaks which claim IDs are valid. When an expired token returns 403 instead of 401, the client doesn't know to refresh its token and the user gets stuck. A validation error that returns 403 instead of 422 gives the client no field-level errors to fix, and the wrong team investigates.

## Guidance

Return 403 only for authenticated users who lack permission to access a resource they can already see exists (e.g., admin endpoints, role-based restrictions). For resources whose existence should be hidden from unauthorized users (claims, prescriptions, health records), return 404 for both "not found" and "not authorized" using `find_by` instead of `find`. Include `meta.required_permission` in 403 responses to guide administrators.

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

**Problem:** Attacker can enumerate valid claim IDs by observing 403 vs 404. The split response codes leak resource existence.

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

**Problem:** Client doesn't know to refresh its token. User gets stuck. Wrong team investigates authorization when the issue is authentication.

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

## Reference

### When to Use 403

| Scenario | Status | Reasoning |
|----------|--------|-----------|
| Veteran A tries to access Veteran B's health records | **403** or **404** | 404 if resource should be hidden (security) |
| User lacks required role (e.g., not an admin) | **403** | Authenticated but missing permission level |
| User account suspended or locked | **403** | Known user but access revoked |
| User tries to DELETE but only has READ permission | **403** | Authenticated but not authorized for action |

### When NOT to Use 403

| Scenario | Wrong | Correct | Reasoning |
|----------|-------|---------|-----------|
| User token expired | 403 | **401** | Authentication failure, not authorization |
| Resource doesn't exist | 403 | **404** | Can't authorize access to non-existent resource |
| Validation fails | 403 | **422** | Data validation, not authorization |
| User shouldn't know resource exists | 403 | **404** | Prevents enumeration attack |
| API key not in request | 403 | **401** | Authentication not provided |

## References

- [RFC 7231 Section 6.5.3](https://tools.ietf.org/html/rfc7231#section-6.5.3)
- [OWASP Access Control](https://owasp.org/www-community/Access_Control)
- Related: [Handle 401 Authentication Errors](06-handle-401-token-ownership.md)
