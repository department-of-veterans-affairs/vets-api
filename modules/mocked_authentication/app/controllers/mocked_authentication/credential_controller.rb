# frozen_string_literal: true

module MockedAuthentication
  class CredentialController < ApplicationController
    skip_before_action :authenticate

    def authorize
      credential_info = params[:credential_info].presence
      state = params[:state].presence
      error = params[:error].presence

      validate_authorize_params(credential_info, state, error)

      credential_info_code = CredentialInfoCreator.new(credential_info: credential_info).perform unless error

      redirect_to RedirectUrlGenerator.new(state: state, code: credential_info_code, error: error).perform
    rescue => e
      render json: { errors: e }, status: :bad_request
    end

    private

    def validate_authorize_params(credential_info, state, error)
      raise SignIn::Errors::MalformedParamsError.new message: 'State is not defined' unless state
      unless credential_info || error
        raise SignIn::Errors::MalformedParamsError.new message: 'Credential Info is not defined'
      end
    end
  end
end
