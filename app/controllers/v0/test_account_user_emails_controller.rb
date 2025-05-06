# frozen_string_literal: true

module V0
  class TestAccountUserEmailsController < ApplicationController
    service_tag 'identity'
    skip_before_action :authenticate

    NAMESPACE = 'test_account_user_email'
    TTL = 2_592_000

    def create
      email_redis_key = SecureRandom.uuid
      Rails.cache.write(email_redis_key, create_params, namespace: NAMESPACE, expires_in: TTL)

      Rails.logger.info("[V0][TestAccountUserEmailsController] create, key:#{email_redis_key}")

      render json: { test_account_user_email_uuid: email_redis_key }, status: :created
    rescue
      render json: { errors: 'invalid params' }, status: :bad_request
    end

    def create_params
      params.require(:email)
    end
  end
end
