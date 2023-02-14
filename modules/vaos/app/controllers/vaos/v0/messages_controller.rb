# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class MessagesController < VAOS::V0::BaseController
      def index
        render json: VAOS::V0::MessagesSerializer.new(messages[:data], meta: messages[:meta])
      end

      def create
        response = messages_service.post_message(appointment_request_id, post_params)
        render json: VAOS::V0::MessagesSerializer.new(response[:data], meta: response[:meta])
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
        @messages ||= messages_service.get_messages(appointment_request_id)
      end

      def messages_service
        VAOS::MessagesService.new(current_user)
      end
    end
  end
end
# :nocov:
