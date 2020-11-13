# frozen_string_literal: true

require 'common/exceptions'

module OpenidAuth
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content, raise: false

    def validate_user
      unless token.client_credentials_token?
        raise Common::Exceptions::RecordNotFound, @current_user.uuid if @current_user.va_profile_status == 'NOT_FOUND'
        raise Common::Exceptions::BadGateway if @current_user.va_profile_status == 'SERVER_ERROR'

        obscure_token = Session.obscure_token(token.to_s)
        Rails.logger.info("Logged in user with id #{@session.uuid}, token #{obscure_token}")
      end
    end

    def fetch_aud
      params['aud']
    end
  end
end
