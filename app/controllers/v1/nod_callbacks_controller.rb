# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

module V1
  class NodCallbacksController < ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include DecisionReviewV1::Appeals::LoggingUtils

    service_tag 'appeal-application'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_header, only: [:create]

    STATSD_KEY_PREFIX = 'api.decision_review.notification_callback'

    DELIVERED_STATUS = 'delivered'

    def create
      return render json: nil, status: :not_found unless enabled?

      payload = JSON.parse(request.body.string)
      status = payload['status']&.downcase

      StatsD.increment("#{STATSD_KEY_PREFIX}.received", tags: { status: })

      if status == DELIVERED_STATUS
        StatsD.increment('silent_failure_avoided', tags: { service: 'appeal-application',
                                                           function: 'appeal submission form or evidence' })
      end

      begin
        NodNotification.create!(payload:, notification_id: payload['id'], status:)
      rescue ActiveRecord::RecordInvalid => e
        log_formatted(**log_params(payload, false), params: { exception_message: e.message })
        return render json: { message: 'failed' }
      end

      log_formatted(**log_params(payload, true))
      render json: { message: 'success' }
    end

    private

    def log_params(payload, is_success)
      {
        key: :decision_review_vanotify_callback,
        form_id: '10182',
        user_uuid: nil,
        upstream_system: 'VANotify',
        body: payload.merge('to' => '<FILTERED>'), # scrub PII from logs
        is_success:,
        params: {
          notification_id: payload['id'],
          callback_status: payload['status']
        }
      }
    end

    def authenticate_header
      authenticate_user_with_token || authenticity_error
    end

    def authenticate_user_with_token
      authenticate_with_http_token do |token|
        is_authenticated = token == bearer_token_secret
        Rails.logger.info('NodCallbacksController received callback', is_authenticated:)

        is_authenticated
      end
    end

    def authenticity_error
      render json: { message: 'Invalid credentials' }, status: :unauthorized
    end

    def enabled?
      Flipper.enabled? :nod_callbacks_endpoint
    end

    def bearer_token_secret
      Settings.dig(:nod_vanotify_status_callback, :bearer_token)
    end
  end
end
