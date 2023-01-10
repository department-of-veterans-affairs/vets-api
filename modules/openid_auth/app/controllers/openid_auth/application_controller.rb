# frozen_string_literal: true

require 'common/exceptions'

module OpenidAuth
  class ApplicationController < ::OpenidApplicationController
    def validate_user
      unless token.static? || token.client_credentials_token? || token.ssoi_token?
        # TB TODO: Remove 'NOT_FOUND', and 'SERVER_ERROR', when MPI cache has cycled
        if [:not_found, 'NOT_FOUND'].include?(@current_user.mpi_status)
          raise Common::Exceptions::RecordNotFound, @current_user.uuid
        end
        raise Common::Exceptions::BadGateway if [:server_error, 'SERVER_ERROR'].include?(@current_user.mpi_status)

        obscure_token = Session.obscure_token(token.to_s)
        Rails.logger.info("Logged in user with id #{@session&.uuid}, token #{obscure_token}")
      end
    end

    def fetch_aud
      params['aud']
    rescue => e
      # Handle a malformed body
      log_message_to_sentry("Error processing request: #{e.message}", :error)
      raise Common::Exceptions::TokenValidationError.new(detail: 'Invalid request', status: 400, code: 400)
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'openid_auth' }
      Raven.tags_context(source: 'openid_auth')
    end
  end
end
