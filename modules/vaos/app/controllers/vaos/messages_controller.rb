# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class MessagesController < ApplicationController
    def index
      render json: MessagesSerializer.new(messages[:data], meta: messages[:meta])
    end

    def create
      response = messages_service.post_request(appointment_request_id, post_params)
      render json: MessagesSerializer.new(response[:data], meta: response[:meta])
    end

    private

    def appointment_request_id
      params[:appointment_request_id]
    end

    def post_params
      params.require(:message_text)
      params.permit(:message_text, :url)
    end

    def messages
      @messages ||= messages_service.get_messages(params[:appointment_request_id])
    end

    def messages_service
      VAOS::MessagesService.for_user(current_user)
    end
  end
end
