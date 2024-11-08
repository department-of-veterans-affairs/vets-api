# frozen_string_literal: true

module V0
  class UserAccountDelegationsController < ApplicationController
    service_tag 'identity'

    def show
      render json: { data: current_user.linked_user_accounts }, status: :ok
    end

    def create
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
