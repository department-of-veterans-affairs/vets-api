# frozen_string_literal: true

require 'claims_api/jwt_encoder'

module ClaimsApi
  class VANotifyFollowUpJob < ClaimsApi::ServiceBase
    sidekiq_options retry: 14

    LOG_TAG = 'va_notify_follow_up_job'
    NON_RETRY_STATUSES = %w[delivered preferences-declined permanent-failure].freeze
    RETRY_STATUSES = %w[sent technical-failure temporary-failure].freeze

    sidekiq_retries_exhausted do |message|
      msg = "Retries exhausted. #{message['error_message']}"

      slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                             channel: '#api-benefits-claims-alerts',
                                             username: 'Failed ClaimsApi::VANotifyFollowUpJob')
      slack_client.notify(msg)
    end

    def perform(notification_id)
      status = notification_response_status(notification_id)
      detail = "Status for notification #{notification_id} was '#{status}'"

      handle_failure(detail) if status == 'permanent-failure'

      unless NON_RETRY_STATUSES.include?(status)
        ClaimsApi::Logger.log(
          'va_follow_up_job',
          detail:
        )
        raise detail
      end
    rescue => e
      ClaimsApi::Logger.log(
        'va_follow_up_job',
        detail: "Failed to check: #{get_error_message(e)}"
      )
      raise e
    end

    private

    def handle_failure(msg)
      job_name = 'ClaimsApi::VANotifyFollowUpJob'
      ClaimsApi::Logger.log(LOG_TAG, detail: msg)
      slack_alert_on_failure(job_name, msg)
    end

    def notification_response_status(notification_id)
      res = client.get(notification_id.to_s)&.body
      res[:status]
    end

    def client
      base_name = Settings.vanotify.client_url || 'https://staging-api.va.gov'

      @token ||= generate_jwt_token
      raise StandardError, 'VA Notify token missing' if @token.nil?

      Faraday.new("#{base_name}/v2/notifications/",
                  headers: { 'Authorization' => "Bearer #{@token}" }) do |f|
        f.response :raise_custom_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end

    def generate_jwt_token
      client_secret = settings.notification_client_secret
      service_id = settings.notify_service_id
      alg = 'HS256'

      ClaimsApi::JwtEncoder.new.encode_va_notify_jwt(alg, service_id, client_secret)
    end

    def settings
      Settings.claims_api.vanotify.services.lighthouse
    end
  end
end
