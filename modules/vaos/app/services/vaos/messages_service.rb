# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class MessagesService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    attr_accessor :user

    STATSD_KEY_PREFIX = 'api.vaos'

    def self.for_user(user)
      rs = VAOS::MessagesService.new
      rs.user = user
      rs
    end

    def get_messages(request_id)
      with_monitoring do
        response = perform(:get, messages_url(request_id), nil, headers)

        {
          data: deserialize(response.body),
          meta: {}
        }
      end
    end

    private

    def deserialize(json_hash)
      json_hash[:appointment_request_message].map { |request| OpenStruct.new(request) }
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def messages_url(request_id)
      "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}" \
        "/appointment-requests/system/var/id/#{request_id}/messages"
    end

    def headers
      super(user)
    end
  end
end
