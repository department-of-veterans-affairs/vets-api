# frozen_string_literal: true

require 'config'

module Identity
  module Config
    class Railtie < Rails::Railtie
      ENV_PREFIXS = %w[IDENTITY_SETTINGS identity_settings].freeze
      ENV_SEPARATOR = '__'
      SETTINGS_FOLDER = 'config/identity_settings'
      ::IdentitySettings = ::Config::Options.new

      config.before_configuration { setup }

      def setup
        if current_env.blank?
          raise StandardError, 'Identity::Config::Railtie current_env not set for IdentitySettings config'
        end

        settings_files.each { |file| ::IdentitySettings.add_source!(file) }
        ::IdentitySettings.add_source!(secrets_source) if secrets_source.present?

        ::IdentitySettings.reload!
      end

      private

      def current_env
        @current_env ||= if Rails.env.local? # rubocop:disable Rails/UnknownEnv
                           Rails.env
                         else
                           ENV.fetch('APPLICATION_ENV', nil)
                         end
      end

      def secrets_env_prefix
        ENV_PREFIXS.find { |prefix| ENV.keys.any? { |key| key.start_with?(prefix) } }
      end

      def settings_files
        ::Config.setting_files(SETTINGS_FOLDER, current_env)
      end

      def secrets_source
        return if secrets_env_prefix.blank?

        ::Config::Sources::EnvSource.new(ENV, prefix: secrets_env_prefix, separator: ENV_SEPARATOR)
      end
    end
  end
end
