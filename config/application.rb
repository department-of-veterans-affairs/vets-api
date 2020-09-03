# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
# require "active_job/railtie"
require 'active_record/railtie'
# require "active_storage/engine"
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "action_mailbox/engine"
# require "action_text/engine"
# require "action_view/railtie"
# require "action_cable/engine"
# require "sprockets/railtie"
require_relative '../lib/http_method_not_allowed'
require_relative '../lib/statsd_middleware'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VetsAPI
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    config.autoloader = :classic

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.relative_url_root = Settings.relative_url_root

    # This prevents rails from escaping html like & in links when working with JSON
    config.active_support.escape_html_entities_in_json = false

    # CORS configuration; see also cors_preflight route
    config.middleware.insert_before 0, Rack::Cors, logger: (-> { Rails.logger }) do
      allow do
        regex = Regexp.new(Settings.web_origin_regex)
        origins { |source, _env| Settings.web_origin.split(',').include?(source) || source.match?(regex) }
        resource '*', headers: :any,
                      methods: :any,
                      credentials: true,
                      expose: %w[
                        X-RateLimit-Limit
                        X-RateLimit-Remaining
                        X-RateLimit-Reset
                        X-Session-Expiration
                        X-CSRF-Token
                      ]
      end
    end

    config.middleware.insert_before(0, HttpMethodNotAllowed)
    config.middleware.use OliveBranch::Middleware, inflection_header: 'X-Key-Inflection'
    config.middleware.use StatsdMiddleware
    config.middleware.use Rack::Attack
    config.middleware.use ActionDispatch::Cookies
    config.middleware.insert_after ActionDispatch::Cookies,
                                   ActionDispatch::Session::CookieStore,
                                   key: 'api_session',
                                   secure: Settings.session_cookie.secure,
                                   http_only: true
  end
end
