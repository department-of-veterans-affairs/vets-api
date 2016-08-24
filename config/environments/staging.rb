Rails.application.configure do
  config.action_dispatch.default_headers = {
    'Access-Control-Allow-Origin' => 'http://localhost:3000',
    'Access-Control-Request-Method' => %w{GET POST OPTIONS}.join(",")
  }
  config.eager_load = true

  # Show full error reports
  config.consider_all_requests_local = true

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
end
