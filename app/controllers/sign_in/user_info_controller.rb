# frozen_string_literal: true

module SignIn
  class UserInfoController < ApplicationController
    service_tag 'identity'

    def show
      authorize access_token, policy_class: SignIn::UserInfoPolicy

      render json: user_info_json, status: :ok
    end

    private

    def user_info_json
      {
        sub: current_user.uuid,
        credential_uuid: current_user.uuid,
        icn: current_user.icn,
        sec_id: current_user.sec_id,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        email:
      }
    end

    def email
      user_verification&.user_credential_email&.credential_email
    end

    def user_verification
      current_user.user_verification
    end
  end
end
