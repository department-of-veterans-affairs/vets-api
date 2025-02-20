# frozen_string_literal: true

require 'claims_api/bgs_client/definitions'
module ClaimsApi
  ##
  # Allows us to retrieve BGS service definitions from free-form endpoint
  # values so that we can adapt `LocalBGS` to `BGSClient` which operates off
  # the service definitions.
  #
  module FindDefinition
    def initialize(external_uid:, external_key:)
      external_uid ||= Settings.bgs.external_uid
      external_key ||= Settings.bgs.external_key

      @external_id =
        BGSClient::ExternalId.new(
          external_uid:,
          external_key:
        )
    end

    class NotDefinedError < StandardError
      def initialize(message)
        message = <<~HEREDOC
          #{message}
          Define beans, services, and actions in `ClaimsApi::BGSClient::Definitions`.
        HEREDOC

        super
      end
    end

    Mod = BGSClient::Definitions

    LOOKUP =
      {}.tap do |lookup|
        # Rather than hardcode a duplicated list of service definitions or
        # polluting the code that this adapts to to care about this temporary
        # adapter logic, we query constants and select the ones that are
        # service definitions.
        Mod.constants.each do |service_mod|
          service_mod = Mod.const_get(service_mod)
          next unless service_mod.const_defined?(:DEFINITION)

          service = service_mod.const_get(:DEFINITION)
          next unless service.is_a?(Mod::Service)

          {}.tap do |actions|
            service_mod.constants.each do |action_mod|
              next if action_mod == :DEFINITION

              action_mod = service_mod.const_get(action_mod)
              next unless action_mod.const_defined?(:DEFINITION)

              action = action_mod.const_get(:DEFINITION)
              next unless action.is_a?(Mod::Action)

              name = action.name
              actions[name] = action
            end

            endpoint = service.full_path
            lookup[endpoint] = {
              service:,
              actions:
            }

            actions.freeze
          end
        end

        lookup.freeze
      end

    class << self
      def for_action(endpoint, action)
        actions = fetch_endpoint(endpoint)[:actions]
        actions.fetch(action) do
          raise NotDefinedError, "Undefined action `#{action}` for service `#{endpoint}`"
        end
      end

      def for_service(endpoint)
        fetch_endpoint(endpoint)[:service]
      end

      private

      def fetch_endpoint(endpoint)
        LOOKUP.fetch(endpoint) do
          raise NotDefinedError, "Undefined service `#{endpoint}`"
        end
      end
    end
  end
end
