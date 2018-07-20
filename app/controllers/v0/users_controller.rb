# frozen_string_literal: true

module V0
  class UsersController < ApplicationController
    def show
      render json: @current_user
    end

    def read_sso_cookie
      render json: decrypt(cookies[:vamhv_session],Settings.sso_cookie_key).split('|').to_json
    end

    private
    def decrypt(payload,key)
      ActiveSupport::MessageEncryptor.new(key).decrypt_and_verify(payload)
    end
  end
end
