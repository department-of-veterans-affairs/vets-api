# frozen_string_literal: true

module CheckIn
  module V2
    class SessionsController < CheckIn::ApplicationController
      def show
        check_in = CheckIn::PatientCheckIn.build(uuid: params[:id])

        render json: check_in.client_error and return unless check_in.valid?

        session_key = "#{Settings.check_in.lorota_v2.redis_session_prefix}_#{check_in.uuid}_read.full"

        unless session[:jwt].present? && Rails.cache.read(session_key, namespace: 'check-in-lorota-v2-cache')
          render json: { data: { permissions: 'read.none', uuid: check_in.uuid, status: 'success' } }
        end
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
