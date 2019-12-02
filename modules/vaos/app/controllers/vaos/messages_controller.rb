# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class MessagesController < ApplicationController

    MASS_ASSIGN_PARAMS_POST = %i[
      appointment_request_id
      is_last_message
      message_date_time
      message_sent
      message_text
      sender_id
      url
    ].freeze

    def index
      render json: MessagesSerializer.new(messages[:data], meta: messages[:meta])
    end

    def create
      response = messages_service.post_request(params[:appointment_request_id], params.require(*MASS_ASSIGN_PARAMS_POST))
      head :no_content # i think this should return the response but the message serializer has system_id and response does not.  i'm not sure it matters.
    end

    private

    def messages
      @messages ||= messages_service.get_messages(params[:appointment_request_id])
    end

    def messages_service
      VAOS::MessagesService.for_user(current_user)
    end
  end
end
