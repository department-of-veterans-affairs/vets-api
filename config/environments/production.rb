# frozen_string_literal: true

require 'config_helper'

Rails.application.configure do
  # Specify environment specific hostname and protocol
  config.hostname = Settings.hostname
  config.protocol = 'https'
  routes.default_url_options = { host: config.hostname, protocol: config.protocol }
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  # config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  # config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  # config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  config.log_tags = {
    request_id: :uuid,
    ref: ->(_request) { AppInfo::GIT_REVISION },
    consumer_id: ->(request) { request.headers['X-Consumer-ID'] },
    consumer_username: ->(request) { request.headers['X-Consumer-Username'] },
    consumer_custom_id: ->(request) { request.headers['X-Consumer-Custom-ID'] },
    credential_username: ->(request) { request.headers['X-Credential-Username'] }
  }

  config.rails_semantic_logger.format = :json
  config.rails_semantic_logger.add_file_appender = false
  config.semantic_logger.add_appender(io: STDOUT,
                                      level: config.log_level,
                                      formatter: config.rails_semantic_logger.format)

  config.semantic_logger.application = if Sidekiq.server?
                                         'vets-api-worker'
                                       else
                                         'vets-api-server'
                                       end

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Log to standard out, with specified formatter
  STDOUT.sync = config.autoflush_log
  logger = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger = ActiveSupport::TaggedLogging.new(logger)

  # Do not dump schema after migrations.
  # config.active_record.dump_schema_after_migration = false
  ConfigHelper.setup_action_mailer(config)
end
