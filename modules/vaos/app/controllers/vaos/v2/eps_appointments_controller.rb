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

        response = OpenStruct.new({
                                    id: appointment[:id],
                                    appointment: appointment,
                                    provider: unless appointment[:provider_service_id].nil?
                                                provider_service.get_provider_service(
                                                  provider_id: appointment[:provider_service_id]
                                                )
                                              end
                                  })

        render json: Eps::EpsAppointmentSerializer.new(response)
      end

      private

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
