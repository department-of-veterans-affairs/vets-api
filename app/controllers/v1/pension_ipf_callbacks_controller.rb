# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

module V1
  class PensionIpfCallbacksController < ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include DecisionReviewV1::Appeals::LoggingUtils

    service_tag 'pension-ipf-callbacks'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_header, only: [:create]

    STATUSES_TO_IGNORE = %w[sent delivered temporary-failure].freeze

    def create
      return render json: nil, status: :not_found unless Flipper.enabled? :pension_ipf_callbacks_endpoint

      payload = JSON.parse(request.body.string)

      # save encrypted request body in database table for non-successful notifications
      payload_status = payload['status']&.downcase
      if STATUSES_TO_IGNORE.exclude? payload_status
        begin
          PensionIpfNotification.create!(payload:)
        rescue ActiveRecord::RecordInvalid => e
          log_formatted(**log_params(payload).merge(is_success: false), params: { exception_message: e.message })
          return render json: { message: 'failed' }
        end
      end

      log_formatted(**log_params(payload).merge(is_success: true))
      render json: { message: 'success' }
    end

    private

    def authenticate_header
      authenticate_user_with_token || authenticity_error
    end

    def authenticate_user_with_token
      Rails.logger.info('pension-ipf-callbacks-69766 - Received request, authenticating')
      authenticate_with_http_token do |token|
        # TODO: Temp logging for debugging Staging issue. Remove after testing
        Rails.logger.info("pension-ipf-callbacks-69766 - Expecting #{bearer_token_secret}")
        Rails.logger.info("pension-ipf-callbacks-69766 - Length: #{bearer_token_secret.length}")
        Rails.logger.info("pension-ipf-callbacks-69766 - Received #{token}")
        Rails.logger.info("pension-ipf-callbacks-69766 - Length: #{token.length}")
        return false if bearer_token_secret.nil?

        Rails.logger.info("pension-ipf-callbacks-69766 - Is equal?: #{token == bearer_token_secret}")
        token == bearer_token_secret
      end
    end

    def authenticity_error
      Rails.logger.info('pension-ipf-callbacks-69766 - Failed to authenticate request')
      render json: { message: 'Invalid credentials' }, status: :unauthorized
    end

    def bearer_token_secret
      Settings.pension_ipf_vanotify_status_callback.bearer_token
    end

    def log_params(payload)
      {
        key: :callbacks,
        form_id: '21P-527EZ',
        user_uuid: nil,
        upstream_system: 'VANotify',
        body: payload.merge('to' => '<FILTERED>') # scrub PII from logs
      }
    end
  end
end
