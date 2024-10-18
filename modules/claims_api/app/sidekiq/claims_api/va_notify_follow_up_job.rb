# frozen_string_literal: true

require 'jwt'

module ClaimsApi
  class VANotifyFollowUpJob < ClaimsApi::ServiceBase
    NON_RETRY_STATUSES = %w[delivered preferences-declined].freeze
    RETRY_STATUSES = %w[sent technical-failure temporary-failure permanent-failure].freeze

    def perform(notification_id)
      status = notification_response_status

      unless NON_RETRY_STATUSES.include?(status)
        self.class.perform_in(60.minutes, notification_id)
        ClaimsApi::Logger.log(
          'va_follow_up_job',
          detail: "Status for notification #{notification_id} was #{status}"
        )
      end
    rescue => e
      ClaimsApi::Logger.log(
        'va_follow_up_job',
        detail: "Failed to check: #{get_error_message(e)}"
      )
      raise e
    end

    private

    def notification_response_status
      res = client.get(notification_id.to_s)&.body
      res[:status]
    end

    def client
      base_name = Settings.vanotify.client_url || 'https://staging-api.va.gov'

      @token = generate_jwt_token
      raise StandardError, 'VA Notify token missing' if @token.nil?

      Faraday.new("#{base_name}/vanotify/v2/notifications/",
                  headers: { 'Authorization' => "Bearer #{@token}" }) do |f|
        f.response :raise_custom_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end

    def generate_jwt_token
      notification_client_secret = settings.notification_client_secret
      notify_service_id = settings.notify_service_id
      # Set headers for JWT
      headers = {
        typ: 'JWT',
        alg: 'HS256'
      }
      # Prepare timestamp in seconds
      current_timestamp = Time.now.to_i
      # Prepare the payload
      data = {
        iss: notify_service_id,
        iat: current_timestamp
      }
      # Encode the token
      JWT.encode(data, notification_client_secret, 'HS256', headers)
    end

    def settings
      Settings.claims_api.vanotify.services.lighthouse
    end
  end
end
