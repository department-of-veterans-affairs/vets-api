# frozen_string_literal: true

require 'logging/third_party_transaction'

module V0
  class UsersController < ApplicationController
    service_tag 'identity'

    def show
      pre_serialized_profile = Users::Profile.new(current_user, @session_object).pre_serialize

      options = {  meta: { errors: pre_serialized_profile.errors } }
      render json: UserSerializer.new(pre_serialized_profile, options), status: pre_serialized_profile.status
    end

    def icn
      render json: { icn: current_user.icn }, status: :ok
    end

    def credential_emails
      emails = current_user.user_account.user_verifications.each_with_object({}) do |verification, credentials|
        credentials[verification.user_credential_email.credential_email.to_sym] =
          verification.user_credential_email.credential_email
      end

      render json: emails
    end
  end
end
