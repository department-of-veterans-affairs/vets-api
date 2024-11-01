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
        credentials[verification.credential_type.to_sym] =
          verification.user_credential_email.credential_email
      end

      render json: emails
    end

    def linked_user_accounts
      render json: { data: current_user.linked_user_accounts }, status: :ok
    end

    def delegate_access
      verified_user_account_icn = validate_verified_user

      UserAccountDelegation.delegate_access(
        verified_user_account_icn:,
        delegated_user_account_icn: current_user.icn
      )
    end

    private

    def validate_verified_user
      verified_user_account_icn = params[:data][:attributes][:verified_user_account_icn]
      raise Common::Exceptions::ParameterMissing, 'verified_user_account_icn' unless verified_user_account_icn

      user_account = UserAccount.find_by(icn: verified_user_account_icn)
      # additional validation of eligibility to have access delegated
      raise Common::Exceptions::RecordNotFound, verified_user_account_icn unless user_account

      verified_user_account_icn
    end
  end
end
