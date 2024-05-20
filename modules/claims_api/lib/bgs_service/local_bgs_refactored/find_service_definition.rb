# frozen_string_literal: true

module ClaimsApi
  class LocalBGSRefactored
    ##
    # Allows us to retrieve BGS service definitions from free-form endpoint
    # values so that we can adapt `LocalBGS` to `BGSClient` which operates off
    # the service definitions.
    #
    module FindServiceDefinition
      class NotDefinedError < StandardError
        def initialize(endpoint)
          message = <<~HEREDOC
            No `bean` and `service` defined for endpoint `#{endpoint}`.
            Define them in `ClaimsApi::BGSClient::Definitions`.
          HEREDOC

          super(message)
        end
      end

      ENDPOINT_SERVICES =
        {}.tap do |lookup|
          # Rather than hardcode a duplicated list of service definitions or
          # polluting the code that this adapts to to care about this temporary
          # adapter logic, we query constants and select the ones that are
          # service definitons.
          mod = BGSClient::Definitions
          mod.constants.each do |service|
            service = mod.const_get(service)
            next unless service.const_defined?(:DEFINITION)

            service = service.const_get(:DEFINITION)
            next unless service.is_a?(mod::Service)

            endpoint = service.full_path
            lookup[endpoint] = service
          end

          lookup.freeze
        end

      class << self
        def perform(endpoint)
          ENDPOINT_SERVICES.fetch(endpoint) do
            raise NotDefinedError, endpoint
          end
        end
      end
    end
  end
end
