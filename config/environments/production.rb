# frozen_string_literal: true

require 'active_support/core_ext/integer/time'
require 'config_helper'

Rails.application.configure do
  # Specify environment specific hostname and protocol
  config.hostname = Settings.hostname
  config.protocol = 'https'
  routes.default_url_options = { host: config.hostname, protocol: config.protocol }

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { 'cache-control' => "public, max-age=#{1.year.to_i}" }

  # store files in aws
  config.active_storage.service = :amazon

  # Enable serving of images, stylesheets, and JavaScripts from an asset server. # TODO: Delete me?
  # config.asset_host = "http://assets.example.com"


  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true # TODO: investigate SSL stuff

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Prepend all log lines with the following tags.
  config.log_tags = {
    request_id: :request_id,
    remote_ip: :remote_ip,
    user_agent: ->(request) { request.user_agent },
    fingerprint: ->(request) { "#{request.remote_ip} #{request.user_agent}" },
    ref: ->(_request) { AppInfo::GIT_REVISION },
    referer: ->(request) { request.headers['Referer'] },
    consumer_id: ->(request) { request.headers['X-Consumer-ID'] },
    consumer_username: ->(request) { request.headers['X-Consumer-Username'] },
    consumer_custom_id: ->(request) { request.headers['X-Consumer-Custom-ID'] },
    credential_username: ->(request) { request.headers['X-Credential-Username'] },
    csrf_token: ->(request) { request.headers['X-Csrf-Token'] }
  }
  # config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.rails_semantic_logger.format = :json
  config.rails_semantic_logger.add_file_appender = false
  config.semantic_logger.add_appender(io: $stdout,
                                      level: config.log_level,
                                      formatter: config.rails_semantic_logger.format)

  config.semantic_logger.application = if Sidekiq.server?
                                         'vets-api-worker'
                                       else
                                         'vets-api-server'
                                       end

  # TODO: Investigate these
  # # Change to "debug" to log everything (including potentially personally-identifiable information!)
  # config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  # # Prevent health checks from clogging up the logs.
  # config.silence_healthcheck_path = "/up"

  # # Don't log any deprecations.
  # config.active_support.report_deprecations = false

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, {
    connect_timeout: 2,
    url: Settings.redis.rails_cache.url,
    expires_in: 30.minutes,
    pool: { size: ENV.fetch('RAILS_MAX_THREADS', 5).to_i }
  }

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: 'example.com' }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Log disallowed deprecations.
  config.active_support.disallowed_deprecation = :log

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Log to standard out, with specified formatter
  $stdout.sync = config.autoflush_log
  logger = ActiveSupport::Logger.new($stdout)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)

  # Do not dump schema after migrations.
  # config.active_record.dump_schema_after_migration = false TODO: # Default is true, so we could remove ths or set to true?
  ConfigHelper.setup_action_mailer(config)

  # Only use :id for inspections in production.
  # config.active_record.attributes_for_inspect = [ :id ] # TODO look into this

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
