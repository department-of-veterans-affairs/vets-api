# frozen_string_literal: true

module VAOS
  class MessagesController < VAOS::BaseController
    def index
      render json: MessagesSerializer.new(messages[:data], meta: messages[:meta])
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
