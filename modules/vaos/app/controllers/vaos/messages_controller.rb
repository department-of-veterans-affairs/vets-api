# frozen_string_literal: true

module VAOS
  class MessagesController < VAOS::BaseController
    def index
      render json: MessagesSerializer.new(messages[:data], meta: messages[:meta])
    end

    def create
      response = messages_service.post_message(appointment_request_id, post_params)
      render json: MessagesSerializer.new(response[:data], meta: response[:meta])
    end

    private

    def appointment_request_id
      params[:appointment_request_id]
    end

    def post_params
      params.require(:message_text)
      params.permit(:message_text)
    end

    def messages
      @messages ||= messages_service.get_messages(params[:appointment_request_id])
    end

    def messages_service
      VAOS::MessagesService.for_user(current_user)
    end
  end
end
