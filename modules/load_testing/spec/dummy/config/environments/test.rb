Rails.application.configure do
  # Basic Rails configuration
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_controller.allow_forgery_protection = false
  config.active_support.deprecation = :stderr
  config.active_support.test_helper = false
  config.active_job.queue_adapter = :test

  # Database configuration
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.maintain_test_schema = true

  # Raise exceptions for disallowed deprecations
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  # Configure logging
  config.log_level = :debug
  config.log_tags = [:request_id]
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }
end 