# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class AppointmentRequestMessagesController < ApplicationController
      # returns a structured list of messages regarding a veteran's appointment request
      def index
        render json: VAOS::V0::MessagesSerializer.new(messages[:data], meta: messages[:meta])
      end

      private

      def appointment_request_id
        params[:appointment_request_id]
      end

      def messages
        @messages ||= messages_service.get_messages(appointment_request_id)
      end

      def messages_service
        VAOS::MessagesService.new(current_user)
      end
    end
  end
end
