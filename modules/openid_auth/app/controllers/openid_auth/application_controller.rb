# frozen_string_literal: true

require 'common/exceptions'

module OpenidAuth
  class ApplicationController < ::OpenidApplicationController
    def validate_user
      unless token.static? || token.client_credentials_token? || token.ssoi_token?
        raise Common::Exceptions::RecordNotFound, @current_user.uuid if @current_user.mpi_status == 'NOT_FOUND'
        raise Common::Exceptions::BadGateway if @current_user.mpi_status == 'SERVER_ERROR'

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
