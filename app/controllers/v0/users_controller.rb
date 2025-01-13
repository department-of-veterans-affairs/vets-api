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
      credential_emails = UserCredentialEmail.where(user_verification: current_user.user_account.user_verifications)
      credential_emails_hash = credential_emails.each_with_object({}) do |credential_email, email_hash|
        email_hash[credential_email.user_verification.credential_type.to_sym] = credential_email.credential_email
      end

      render json: credential_emails_hash
    end
  end
end
