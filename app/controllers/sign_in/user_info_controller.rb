# frozen_string_literal: true

module SignIn
  class UserInfoController < ApplicationController
    service_tag 'identity'

    def show
      authorize access_token, policy_class: SignIn::UserInfoPolicy
      user_info = SignIn::UserInfoGenerator.new(user: current_user).perform

      if user_info.valid?
        render json: user_info.serializable_hash, status: :ok
      else
        error = user_info.errors.full_messages.join(', ')

        Rails.logger.error('[SignIn][UserInfoController] Invalid user_info', error:)
        render json: { error: }, status: :bad_request
      end
    end

    private

    def user_verification
      current_user.user_verification
    end
  end
end
