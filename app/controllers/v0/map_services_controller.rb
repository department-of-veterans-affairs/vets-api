# frozen_string_literal: true

require 'map/security_token/service'

module V0
  class MapServicesController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    # POST /v0/map_services/:application/token
    def token
      icn = @service_account_access_token.user_attributes['icn']
      result = MAP::SecurityToken::Service.new.token(application: params[:application].to_sym, icn:, cache: false)

      render json: result, status: :ok
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout, JWT::DecodeError
      render json: sts_client_error, status: :bad_gateway
    rescue MAP::SecurityToken::Errors::ApplicationMismatchError
      render json: application_mismatch_error, status: :bad_request
    rescue MAP::SecurityToken::Errors::MissingICNError
      render json: missing_icn_error, status: :bad_request
    end

    private

    def sts_client_error
      {
        error: 'server_error',
        error_description: 'STS failed to return a valid token.'
      }
    end

    def application_mismatch_error
      {
        error: 'invalid_request',
        error_description: 'Application mismatch detected.'
      }
    end

    def missing_icn_error
      {
        error: 'invalid_request',
        error_description: 'Service account access token does not contain an ICN in `user_attributes` claim.'
      }
    end
  end
end
