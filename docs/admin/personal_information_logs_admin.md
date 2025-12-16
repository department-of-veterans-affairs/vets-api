# Personal Information Logs Admin UI

A simple, extensible admin interface for querying and exporting PersonalInformationLog data with GitHub OAuth authentication and team-based access control.

## Features

- **GitHub OAuth Authentication**: Secure access via GitHub OAuth (like Flipper/Sidekiq admin)
- **Team-Based Access Control**: Teams only see logs matching their configured patterns
- **Query by Error Class**: Filter logs by specific error classes
- **Date Range Filtering**: Filter logs by creation date
- **Pagination**: Browse logs with configurable page sizes (25, 50, 100, 250)
- **CSV Export**: Export filtered results to CSV (up to 10,000 records)
- **Detail View**: View individual logs with decrypted data

## Quick Start

### 1. Start the Server

```bash
bin/dev
```

### 2. Access the Admin Panel

Open your browser to:
```
http://localhost:3000/admin/personal_information_logs
```

In development mode without GitHub OAuth configured, the dashboard is accessible without authentication.

### 3. Query Logs

- Use the filter form to search by:
  - Error Class (dropdown of all classes you have access to)
  - From Date
  - To Date
  - Results per page

- Click "Filter" to apply
- Click "Clear" to reset filters

### 4. Export Data

Click "Export to CSV" to download the current filtered results (max 10,000 records).

### 5. View Details

Click "View" on any log row to see the full decrypted data in JSON format.

## Authentication & Authorization

### GitHub OAuth Setup

The dashboard uses GitHub OAuth for authentication, similar to Flipper and Sidekiq admin UIs.

#### Configuration

In `config/settings.yml` (or environment-specific files):

```yaml
pii_log_dashboard:
  github_oauth_key: <%= ENV['pii_log_dashboard__github_oauth_key'] %>
  github_oauth_secret: <%= ENV['pii_log_dashboard__github_oauth_secret'] %>
  github_organization: department-of-veterans-affairs
  # Admin team can view ALL logs
  admin_github_team: <%= ENV['pii_log_dashboard__admin_github_team'] %>
  # Team-specific access mappings
  team_access:
    - error_class_pattern: 'ClaimsApi::*'
      github_team: 12345678
    - error_class_pattern: 'MyHealth::*'
      github_team: 87654321
    - error_class_pattern: 'HealthCareApplication*'
      github_team: 11111111
```

#### Getting GitHub Team IDs

Use the GitHub API to find your team ID:

```bash
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/orgs/department-of-veterans-affairs/teams/YOUR_TEAM_SLUG
```

### Team-Based Access Control

Each team can only see `PersonalInformationLog` entries matching their configured patterns.

#### Pattern Syntax

1. **Exact Match**: `'ClaimsApi::VA526ez'` - matches only that exact error class
2. **Wildcard Prefix**: `'ClaimsApi::*'` - matches all classes starting with `ClaimsApi::`
3. **Regex Pattern**: `'/^Lighthouse/'` - matches classes starting with `Lighthouse`

#### Access Levels

| User Type | Access |
|-----------|--------|
| Admin Team Member | Full access to all logs |
| Team with Pattern Match | Only logs matching their team's patterns |
| Org Member (no team match) | Access denied |
| Non-Org Member | Access denied |

### Local Development

In development, if `github_oauth_key` is not set, the dashboard allows unauthenticated access for testing.

To test authentication locally:

1. Create a GitHub OAuth App at https://github.com/settings/developers
2. Set callback URL to: `http://localhost:3000/admin/personal_information_logs/auth/github/callback`
3. Add to `config/settings.local.yml`:

```yaml
pii_log_dashboard:
  github_oauth_key: your_client_id
  github_oauth_secret: your_client_secret
  github_organization: department-of-veterans-affairs
  admin_github_team: 6394772  # Your team ID
```

## API Endpoints

The admin panel provides both HTML and JSON responses:

### List Logs
```
GET /admin/personal_information_logs
GET /admin/personal_information_logs.json
```

Query parameters:
- `error_class` - Filter by error class
- `from_date` - Filter by minimum date (YYYY-MM-DD)
- `to_date` - Filter by maximum date (YYYY-MM-DD)
- `page` - Page number
- `per_page` - Results per page (default: 25)

### View Single Log
```
GET /admin/personal_information_logs/:id
GET /admin/personal_information_logs/:id.json
```

### Export to CSV
```
GET /admin/personal_information_logs/export
```

Same query parameters as list endpoint.

## Team Access Configuration Examples

### Example: Multi-Team Setup

```yaml
pii_log_dashboard:
  github_oauth_key: <%= ENV['pii_log_dashboard__github_oauth_key'] %>
  github_oauth_secret: <%= ENV['pii_log_dashboard__github_oauth_secret'] %>
  github_organization: department-of-veterans-affairs
  admin_github_team: 6394772  # backend-review-group - full access
  team_access:
    # Claims API Team
    - error_class_pattern: 'ClaimsApi::*'
      github_team: 12345678
    
    # My Health Team (Prescriptions, Messaging, Medical Records)
    - error_class_pattern: 'MyHealth::*'
      github_team: 87654321
    - error_class_pattern: 'Rx::*'
      github_team: 87654321
    - error_class_pattern: 'SM::*'
      github_team: 87654321
    
    # Health Care Applications Team
    - error_class_pattern: 'HealthCareApplication*'
      github_team: 11111111
    
    # Decision Review Team
    - error_class_pattern: '/^DecisionReview/'
      github_team: 22222222
```

### Finding Error Classes in Your Codebase

To see what error classes are being logged:

```ruby
# In Rails console
PersonalInformationLog.distinct.pluck(:error_class).sort
```

Common patterns in vets-api:
- `HealthCareApplication ValidationError`
- `HealthCareApplication FailedWontRetry`
- `ClaimsApi::VA526ez::V2`
- Form-specific classes like `Form526Submission`

## Extending the UI

The admin panel is designed to be extensible. Here's how to add new queries:

### 1. Add New Filter to Controller

Edit `app/controllers/admin/personal_information_logs_controller.rb`:

```ruby
def index
  @logs = PersonalInformationLog.order(created_at: :desc)
  
  # Add your new filter
  if params[:your_field].present?
    @logs = @logs.where(your_field: params[:your_field])
  end
  
  # ... existing filters ...
end
```

### 2. Add Filter to View

Edit `app/views/admin/personal_information_logs/index.html.erb`:

```erb
<div class="filter-group">
  <label for="your_field">Your Field</label>
  <%= text_field_tag :your_field, params[:your_field] %>
</div>
```

### 3. Add to Export Method

Update the `export` method in the controller to include your new filter:

```ruby
def export
  logs = PersonalInformationLog.order(created_at: :desc)
  logs = logs.where(your_field: params[:your_field]) if params[:your_field].present?
  # ... rest of method ...
end
```

## Testing

Run the request specs:
```bash
bundle exec rspec spec/requests/admin/personal_information_logs_spec.rb
```

## Files

- `app/controllers/admin/personal_information_logs_controller.rb` - Main controller with auth
- `app/views/admin/personal_information_logs/index.html.erb` - List view with auth UI
- `app/views/admin/personal_information_logs/show.html.erb` - Detail view
- `lib/pii_log_dashboard/route_authorization_constraint.rb` - Route constraint (optional)
- `lib/pii_log_dashboard/github_authentication.rb` - Sinatra-style auth helper
- `config/routes.rb` - Admin namespace routes with auth callbacks

## Database

The admin panel uses the existing `personal_information_logs` table with Lockbox encryption. No database changes required.

## Environment Variables

For production deployment, set these environment variables:

| Variable | Description |
|----------|-------------|
| `pii_log_dashboard__github_oauth_key` | GitHub OAuth App Client ID |
| `pii_log_dashboard__github_oauth_secret` | GitHub OAuth App Client Secret |
| `pii_log_dashboard__admin_github_team` | GitHub Team ID for admin access |
| `pii_log_dashboard__team_access` | JSON array of team access mappings |

### Setting up team_access via Environment Variable

```bash
export pii_log_dashboard__team_access='[{"error_class_pattern":"ClaimsApi::*","github_team":12345678},{"error_class_pattern":"MyHealth::*","github_team":87654321}]'
```

## Production Considerations

Before deploying to production:

1. ✅ **Authentication** - GitHub OAuth is implemented
2. ✅ **Team-Based Access** - Users only see data matching their team patterns
3. **Add Audit Logging** - Consider tracking who accessed what data
4. **Add Rate Limiting** - Prevent abuse of export functionality
5. **Review Data Exposure** - Ensure PII is properly masked if needed
6. **Set Permissions** - Configure team_access mappings for each team

## Support

For issues or questions, see the main vets-api documentation.
