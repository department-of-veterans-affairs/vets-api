# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class MessagesController < ApplicationController
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
