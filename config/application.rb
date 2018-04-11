# frozen_string_literal: true

require File.expand_path('../boot', __FILE__)

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
# require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "action_view/railtie"
# require "sprockets/railtie"
require_relative '../lib/http_method_not_allowed'
require_relative '../lib/statsd_middleware'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VetsAPI
  class Application < Rails::Application

    #config.before_initialize do
    #  VbaDocuments::Engine.instance.initializers.map{ |e| e.run Rails.application }
    #end

    # This needs to be enabled for Shrine to surface errors properly for
    # file uploads.
    config.active_record.raise_in_transactional_callbacks = true
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.api_only = true

    config.relative_url_root = Settings.relative_url_root

    # This prevents rails from escaping html like & in links when working with JSON
    config.active_support.escape_html_entities_in_json = false

    paths_name = Rails.env.development? ? 'autoload' : 'eager_load'
    config.public_send("#{paths_name}_paths") << Rails.root.join('lib')
    config.eager_load_paths << Rails.root.join('app')

    # CORS configuration; see also cors_preflight route
    config.middleware.insert_before 0, 'Rack::Cors', logger: (-> { Rails.logger }) do
      allow do
        origins { |source, _env| Settings.web_origin.split(',').include?(source) }
        resource '*', headers: :any,
                      methods: :any,
                      credentials: true,
                      expose: [
                        'X-RateLimit-Limit',
                        'X-RateLimit-Remaining',
                        'X-RateLimit-Reset'
                      ]
      end
    end

    config.middleware.insert_before(0, HttpMethodNotAllowed)
    config.middleware.use 'OliveBranch::Middleware'
    config.middleware.use 'StatsdMiddleware'
    config.middleware.use 'Rack::Attack'

  end
end
