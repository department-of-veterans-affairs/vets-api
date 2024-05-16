# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequest
      class BaseController < ApplicationController
        # TODO: Figure out appropriate status codes for various upstream service
        # communication failure modes. Using:
        #   https://opensource.zalando.com/restful-api-guidelines/#http-status-codes-and-errors
        concerning :ErrorHandling do
          included do
            bad_gateway_errors = [
              BGSClient::Error::BGSFault,
              BGSClient::Error::ConnectionFailed,
              BGSClient::Error::SSLError
            ]

            rescue_from(*bad_gateway_errors) do |error|
              error = ::Common::Exceptions::BadGateway.new(detail: error.message)
              render_error(error)
            end

            rescue_from(BGSClient::Error::TimeoutError) do
              error = ::Common::Exceptions::GatewayTimeout.new
              render_error(error)
            end
          end
        end
      end
    end
  end
end
