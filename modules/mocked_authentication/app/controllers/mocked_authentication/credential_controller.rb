# frozen_string_literal: true

require 'mockdata/reader'

module MockedAuthentication
  class CredentialController < ApplicationController
    def authorize
      credential_info = params[:credential_info].presence
      state = params[:state].presence
      error = params[:error].presence

      validate_authorize_params(credential_info, state, error)

      credential_info_code = CredentialInfoCreator.new(credential_info:).perform unless error

      redirect_to RedirectUrlGenerator.new(state:, code: credential_info_code, error:).perform
    rescue => e
      render json: { errors: e }, status: :bad_request
    end

    def credential_list
      type = params[:type].presence

      validate_index_params(type)
      mock_profiles = Mockdata::Reader.find_credentials(credential_type: type)

      render json: { mock_profiles: }
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

    def validate_index_params(type)
      unless SignIn::Constants::Auth::CSP_TYPES.include?(type)
        raise SignIn::Errors::MalformedParamsError.new message: 'Invalid credential provider type'
      end
    end
  end
end
