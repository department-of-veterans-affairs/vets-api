# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

module V1
  class DecisionReviewNotificationCallbacksController < ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include DecisionReviewV1::Appeals::LoggingUtils

    service_tag 'appeal-application'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_header, only: [:create]
    before_action :log_non_module_controller

    STATSD_KEY_PREFIX = 'api.decision_review.notification_callback'

    DELIVERED_STATUS = 'delivered'

    APPEAL_TYPE_TO_SERVICE_MAP = {
      'HLR' => 'higher-level-review',
      'NOD' => 'board-appeal',
      'SC' => 'supplemental-claims'
    }.freeze

    VALID_FUNCTION_TYPES = %w[form evidence secondary_form].freeze

    def create
      return render json: nil, status: :not_found unless enabled?

      payload = JSON.parse(request.body.string)
      status = payload['status']&.downcase
      reference = payload['reference']

      StatsD.increment("#{STATSD_KEY_PREFIX}.received", tags: { status: })
      send_silent_failure_avoided_metric(reference) if status == DELIVERED_STATUS

      DecisionReviewNotificationAuditLog.create!(notification_id: payload['id'], reference:, status:, payload:)

      log_formatted(**log_params(payload, true))
      render json: { message: 'success' }
    rescue => e
      log_formatted(**log_params(payload, false), params: { exception_message: e.message })
      render json: { message: 'failed' }
    end

    private

    def log_non_module_controller
      Rails.logger.warn({
                          message: 'Calling decision reviews controller outside module',
                          action: 'Notification callbacks controller'
                        })
    end

    def log_params(payload, is_success)
      {
        key: :decision_review_notification_callback,
        form_id: '995',
        user_uuid: nil,
        upstream_system: 'VANotify',
        body: payload.merge('to' => '<FILTERED>'), # scrub PII from logs
        is_success:,
        params: {
          notification_id: payload['id'],
          status: payload['status']
        }
      }
    end

    def send_silent_failure_avoided_metric(reference)
      service_name, function_type = parse_reference_value(reference)
      tags = ["service:#{service_name}", "function: #{function_type} submission to Lighthouse"]
      StatsD.increment('silent_failure_avoided', tags:)
    rescue => e
      Rails.logger.error('Failed to send silent_failure_avoided metric', params: { reference:, message: e.message })
    end

    def parse_reference_value(reference)
      appeal_type, function_type = reference.split('-')
      raise 'Invalid function_type' unless VALID_FUNCTION_TYPES.include? function_type

      [APPEAL_TYPE_TO_SERVICE_MAP.fetch(appeal_type.upcase), function_type]
    end

    def authenticate_header
      authenticate_user_with_token || authenticity_error
    end

    def authenticate_user_with_token
      authenticate_with_http_token do |token|
        is_authenticated = token == bearer_token_secret
        Rails.logger.info('DecisionReviewNotificationCallbacksController callback received', is_authenticated:)

        is_authenticated
      end
    end

    def authenticity_error
      render json: { message: 'Invalid credentials' }, status: :unauthorized
    end

    def bearer_token_secret
      Settings.nod_vanotify_status_callback.bearer_token
    end

    def enabled?
      Flipper.enabled? :nod_callbacks_endpoint
    end
  end
end
