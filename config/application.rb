# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'active_storage_validations'
require_relative '../lib/identity/config/railtie'
require_relative '../lib/http_method_not_allowed'
require_relative '../lib/source_app_middleware'
require_relative '../lib/statsd_middleware'
require_relative '../lib/faraday_adapter_socks/faraday_adapter_socks'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/olive_branch_patch'

module VetsAPI
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # https://guides.rubyonrails.org/configuring.html#default-values-for-target-version-7-0
    config.load_defaults 7.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # RAILS 7 CONFIG START
    # 7.1
    config.add_autoload_paths_to_load_path = true
    config.active_record.raise_on_assign_to_attr_readonly = false

    # 7.0
    config.action_controller.raise_on_open_redirects = false

    # RAILS 7 CONFIG END

    # Active Record Encryption
    # see: https://guides.rubyonrails.org/active_record_encryption.html
    # ONLY USED FOR CONSOLE1984
    config.active_record.encryption.primary_key = Settings.active_record_encryption.primary_key
    config.active_record.encryption.deterministic_key = Settings.active_record_encryption.deterministic_key
    config.active_record.encryption.key_derivation_salt = Settings.active_record_encryption.key_derivation_salt

    # Console1984
    # see: https://github.com/basecamp/console1984/tree/master?tab=readme-ov-file#configuration
    config.console1984.ask_for_username_if_empty = true
    config.console1984.incinerate_after = 1.year
    config.console1984.production_data_warning = <<~TXT
      You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only.

      By using this IS (which includes any device attached to this IS), you consent to the following conditions:

      The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations.

      At any time, the USG may inspect and seize data stored on this IS. Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose.

      This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy.

      Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work products, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work products are private and confidential. See User Agreement for details.
    TXT

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.relative_url_root = Settings.relative_url_root

    # This prevents rails from escaping html like & in links when working with JSON
    config.active_support.escape_html_entities_in_json = false

    # CORS configuration; see also cors_preflight route
    config.middleware.insert_before 0, Rack::Cors, logger: -> { Rails.logger } do
      allow do
        regex = Regexp.new(Settings.web_origin_regex)
        web_origins = Settings.web_origin.split(',') + Array(IdentitySettings.sign_in.web_origins)

        origins { |source, _env| web_origins.include?(source) || source.match?(regex) }
        resource '*', headers: :any,
                      methods: :any,
                      credentials: true,
                      expose: %w[
                        Timing-Allow-Origin
                        X-RateLimit-Limit
                        X-RateLimit-Remaining
                        X-RateLimit-Reset
                        X-Session-Expiration
                        X-CSRF-Token
                        X-Request-Id
                      ]
      end
    end

    # combats the "Flipper::Middleware::Memoizer appears to be running twice" error
    # followed suggestions to disable memoize config
    config.flipper.memoize = false

    config.middleware.insert_before(0, HttpMethodNotAllowed)
    config.middleware.use OliveBranch::Middleware, inflection_header: 'X-Key-Inflection'
    config.middleware.use SourceAppMiddleware
    config.middleware.use StatsdMiddleware
    config.middleware.use Rack::Attack
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use Warden::Manager do |config|
      config.failure_app = proc do |_env|
        body = { error: 'Unauthorized', code: 401 }.to_json
        [401, { 'Content-Type' => 'application/json' }, [body]]
      end
      config.intercept_401 = false
      config.default_strategies :github

      # Sidekiq Web configuration
      config.scope_defaults :sidekiq, config: {
        client_id: Settings.sidekiq.github_oauth_key,
        client_secret: Settings.sidekiq.github_oauth_secret,
        scope: 'read:org',
        redirect_uri: 'sidekiq/auth/github/callback'
      }

      config.scope_defaults :coverband, config: {
        client_id: Settings.coverband.github_oauth_key,
        client_secret: Settings.coverband.github_oauth_secret,
        scope: 'read:org',
        redirect_uri: 'coverband/auth/github/callback'
      }

      config.scope_defaults :flipper, config: {
        client_id: Settings.flipper.github_oauth_key,
        client_secret: Settings.flipper.github_oauth_secret,
        scope: 'read:org',
        redirect_uri: 'flipper/auth/github/callback'
      }

      config.serialize_from_session { |key| Warden::GitHub::Verifier.load(key) }
      config.serialize_into_session { |user| Warden::GitHub::Verifier.dump(user) }
    end
    config.middleware.insert_after ActionDispatch::Cookies,
                                   ActionDispatch::Session::CookieStore,
                                   key: 'api_session',
                                   secure: IdentitySettings.session_cookie.secure,
                                   http_only: true

    # These files do not contain auto-loaded ruby classes,
    #   they are loaded through app/sidekiq/education_form/forms/base.rb
    Rails.autoloaders.main.ignore(Rails.root.join('app', 'sidekiq', 'education_form', 'templates', '1990-disclosure'))
  end
end
