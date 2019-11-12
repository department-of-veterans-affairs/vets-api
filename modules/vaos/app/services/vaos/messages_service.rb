# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class MessagesService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    attr_reader :user, :request_id

    STATSD_KEY_PREFIX = 'api.vaos'

    def self.for_user(user)
      @user = user
    end

    def get_messages(request_id)
      with_monitoring do
        response = perform(:get, messages_url(request_id), headers)

        {
          data: deserialize(response.body),
          meta: {}
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def deserialize(json_hash)
      json_hash[:messages].map { |request| OpenStruct.new(request) }
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def messages_url(request_id)
      "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}/appointments" +
      "/system/var/id/#{request_id}/messages"
    end

    def headers
      super(user)
    end
  end
end
