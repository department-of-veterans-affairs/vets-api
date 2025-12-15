# frozen_string_literal: true

module TravelPay
  class ApiVersions
    class << self
      ##
      # Returns a hash of all API versions for a resource
      # Useful for passing to client initializers
      #
      # @param resource [Symbol, String] The resource name (:claims or :documents)
      # @param user [User, nil] Optional user for feature flag checks
      #
      # @return [Hash] Hash mapping actions to API versions
      #   e.g., { get_all: 'v3', create: 'v2', submit: 'v3' }
      #
      # @example
      #   versions = TravelPay::ApiVersions.versions_for(resource: :claims)
      #   # => { get_all: 'v2', get_by_id: 'v2', create: 'v2', submit: 'v2' }
      #
      #   versions = TravelPay::ApiVersions.versions_for(resource: :claims, user: current_user)
      #   # => { get_all: 'v3', get_by_id: 'v3', create: 'v3', submit: 'v3' } (if flag enabled)
      #
      def versions_for(resource:, user: nil)
        resource_str = resource.to_s
        resource_config = config.dig(resource_str) || {}

        resource_config.each_with_object({}) do |(action, version), hash|
          # Check feature flag override first
          flag = feature_flag_for(resource_str, action)
          if flag && flag_enabled?(flag, user)
            hash[action.to_sym] = 'v3'
          else
            hash[action.to_sym] = version
          end
        end
      end

      ##
      # Reloads the configuration from the YAML file
      # Useful for development or testing
      #
      def reload!
        @config = nil
      end

      private

      ##
      # Loads and caches the configuration from YAML
      # In development, reloads on each call for easier iteration
      #
      def config
        if Rails.env.development?
          load_config
        else
          @config ||= load_config
        end
      end

      ##
      # Loads the YAML configuration file
      #
      def load_config
        YAML.load_file(config_path)
      end

      ##
      # Returns the path to the configuration file
      #
      def config_path
        Rails.root.join('modules/travel_pay/config/travel_pay_api_versions.yml')
      end

      ##
      # Returns the feature flag for a given resource and action
      #
      # @param resource [String] The resource name
      # @param action [String] The action name
      # @return [Symbol, nil] The feature flag symbol or nil if not configured
      #
      def feature_flag_for(resource, action)
        config.dig('feature_flag_overrides', resource, action)&.to_sym
      end

      ##
      # Checks if a feature flag is enabled
      # Handles both user-specific and global flags
      #
      # @param flag [Symbol] The feature flag name
      # @param user [User, nil] Optional user for user-specific flags
      # @return [Boolean] Whether the flag is enabled
      #
      def flag_enabled?(flag, user)
        if user
          Flipper.enabled?(flag, user)
        else
          Flipper.enabled?(flag)
        end
      end
    end
  end
end
