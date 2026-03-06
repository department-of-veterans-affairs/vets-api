# Personal Information Logs Admin UI

A simple, extensible admin interface for querying and exporting PersonalInformationLog data.

## Features

- **Query by Error Class**: Filter logs by specific error classes
- **Date Range Filtering**: Filter logs by creation date
- **Pagination**: Browse logs with configurable page sizes (25, 50, 100, 250)
- **CSV Export**: Export filtered results to CSV (up to 10,000 records)
- **Detail View**: View individual logs with decrypted data
- **No Authentication**: Currently open access (ready to add auth later)

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

### 3. Query Logs

- Use the filter form to search by:
  - Error Class (dropdown of all classes)
  - From Date
  - To Date
  - Results per page

- Click "Filter" to apply
- Click "Clear" to reset filters

### 4. Export Data

Click "Export to CSV" to download the current filtered results (max 10,000 records).

### 5. View Details

Click "View" on any log row to see the full decrypted data in JSON format.

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

## Adding Authentication

When you're ready to add authentication, you have several options:

### Option 1: Simple HTTP Basic Auth

Add to controller:
```ruby
http_basic_authenticate_with name: ENV['ADMIN_USER'], password: ENV['ADMIN_PASS']
```

### Option 2: GitHub OAuth (like Flipper admin)

1. Create a constraint class:
```ruby
# lib/admin/authorization_constraint.rb
module Admin
  class AuthorizationConstraint
    def self.matches?(request)
      # Your auth logic here
      request.session[:github_user].present?
    end
  end
end
```

2. Update routes:
```ruby
namespace :admin, constraints: Admin::AuthorizationConstraint do
  resources :personal_information_logs
end
```

### Option 3: Role-Based Access

Check user role in controller:
```ruby
before_action :require_admin

def require_admin
  raise Forbidden unless current_user&.admin?
end
```

## Testing

Run the controller specs:
```bash
bundle exec rspec spec/controllers/admin/personal_information_logs_controller_spec.rb
```

## Files Created

- `app/controllers/admin/personal_information_logs_controller.rb` - Main controller
- `app/views/admin/personal_information_logs/index.html.erb` - List view
- `app/views/admin/personal_information_logs/show.html.erb` - Detail view
- `config/routes.rb` - Added admin namespace routes

## Database

The admin panel uses the existing `personal_information_logs` table with Lockbox encryption. No database changes required.

## Example Data

To test with sample data, use the Rails console:

```ruby
# Create a test log
PersonalInformationLog.create!(
  error_class: 'TestError',
  data: { test: 'data', user: 'info' }
)

# Or trigger from a real use case
# See app/models/health_care_application.rb lines 109 and 304 for examples
```

## Production Considerations

Before deploying to production:

1. **Add Authentication** - Use one of the methods above
2. **Add Audit Logging** - Track who accessed what data
3. **Add Rate Limiting** - Prevent abuse of export functionality
4. **Review Data Exposure** - Ensure PII is properly masked if needed
5. **Add Indexes** - Consider adding database indexes for common queries
6. **Set Permissions** - Restrict access to authorized personnel only

## Support

For issues or questions, see the main vets-api documentation.
