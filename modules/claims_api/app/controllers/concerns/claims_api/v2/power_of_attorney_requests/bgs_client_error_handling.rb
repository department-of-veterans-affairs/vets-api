# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      # Implements VA API Standards for upstream service errors:
      #   https://department-of-veterans-affairs.github.io/va-api-standards/errors/
      #
      # In particular, BGS error messaging is obfuscated from the consumer.
      module BGSClientErrorHandling
        extend ActiveSupport::Concern

        included do
          bad_gateway_errors = [
            BGSClient::Error::BGSFault,
            BGSClient::Error::ConnectionFailed,
            BGSClient::Error::SSLError
          ]

          rescue_from(*bad_gateway_errors) do
            render_error(::Common::Exceptions::BadGateway.new)
          end

          rescue_from(BGSClient::Error::TimeoutError) do
            render_error(::Common::Exceptions::GatewayTimeout.new)
          end
        end
      end
    end
  end
end
