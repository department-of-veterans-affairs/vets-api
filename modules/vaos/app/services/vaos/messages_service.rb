# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class MessagesService < VAOS::SessionService
    def get_messages(request_id)
      with_monitoring do
        response = perform(:get, messages_url(request_id), nil, headers)

        {
          data: deserialize(response.body),
          meta: {}
        }
      end
    end

    def post_message(request_id, request_object_body)
      with_monitoring do
        params = VAOS::MessageForm.new(user, request_id, request_object_body).params
        response = perform(:post, messages_url(request_id), params, headers)

        if response.status == 200
          {
            data: message_struct(response.body),
            meta: {}
          }
        else
          handle_error(response)
        end
      end
    end

    private

    def handle_error(response)
      key = response.status == 204 ? 'VAOS_204' : nil
      raise Common::Exceptions::BackendServiceException.new(key, {}, response.status, response.body)
    end

    def deserialize(json_hash)
      json_hash[:appointment_request_message].map { |message| message_struct(message) }
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def message_struct(message)
      OpenStruct.new(message.except(:sender_id))
    end

    def messages_url(request_id)
      "/var/VeteranAppointmentRequestService/v4/rest/appointment-service/patient/ICN/#{user.icn}" \
        "/appointment-requests/system/var/id/#{request_id}/messages"
    end
  end
end
