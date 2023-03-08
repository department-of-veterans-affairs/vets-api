# frozen_string_literal: true

module MockedAuthentication
  class CredentialProvidersController < ApplicationController
    skip_before_action :authenticate

    def authorize
      mock_credential = MockCredentialInfoCreator.new(credential_info: params[:credential_info]).perform
      render json: { credential_info_code: mock_credential.credential_info_code }
    rescue => e
      render json: { errors: e }, status: :bad_request
    end
  end
end
