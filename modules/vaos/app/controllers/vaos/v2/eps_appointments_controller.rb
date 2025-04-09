# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointmentsController < VAOS::BaseController
      def show
        appointment = appointment_service.get_appointment(
          appointment_id: eps_appointment_id,
          retrieve_latest_details: true
        )

        raise Common::Exceptions::RecordNotFound, message: 'Record not found' if appointment[:state] == 'draft'

        provider = fetch_provider(appointment)
        response = OpenStruct.new(
          id: appointment[:id],
          appointment:,
          provider:
        )

        render json: Eps::EpsAppointmentSerializer.new(response)
      end

      private

      ##
      # Fetches provider information for the given appointment.
      #
      # @param appointment [Hash] The appointment data containing provider service ID
      # @return [Object, nil] Provider object or nil if no provider ID is found
      def fetch_provider(appointment)
        provider_id = appointment[:provider_service_id]
        return nil if provider_id.nil?

        provider_service.get_provider_service(provider_id:)
      end

      def eps_appointment_id
        params.require(:id)
      end

      def vaos_serializer
        @vaos_serializer ||= VAOS::V2::VAOSSerializer.new
      end

      def provider_service
        @provider_service ||= Eps::ProviderService.new(current_user)
      end

      def appointment_service
        @appointment_service ||= Eps::AppointmentService.new(current_user)
      end

      def provider
        provider_service.get_provider_service(provider_id: params[:provider_id])
      end
    end
  end
end
