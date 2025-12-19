# frozen_string_literal: true

module SignIn
  class UserInfoController < ApplicationController
    service_tag 'identity'

    def show
      authorize access_token, policy_class: SignIn::UserInfoPolicy
      user_info = SignIn::UserInfo.from_user(current_user)

      render json: user_info.serializable_hash, status: :ok
    end

    private

    def user_verification
      current_user.user_verification
    end
  end
end
