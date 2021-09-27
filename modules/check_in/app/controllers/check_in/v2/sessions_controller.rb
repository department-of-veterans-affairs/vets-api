# frozen_string_literal: true

module CheckIn
  module V2
    class SessionsController < CheckIn::ApplicationController
      def show
        head :not_implemented
      end

      def create
        head :not_implemented
      end

      private

      def session_params
        params.require(:session).permit(:uuid, :last4, :last_name)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_multiple_appointment_support')
      end
    end
  end
end
