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

        referral_detail = nil
        if appointment.dig(:referral, :referral_number).present?
          begin
            referral_detail = ccra_referral_service.get_referral(
              appointment.dig(:referral, :referral_number),
              '2' # Mode parameter, hard-coded based on examples
            )
          rescue => e
            # Log error but continue with the request
            Rails.logger.error "Failed to retrieve referral details: #{e.message}"
          end
        end

        response = OpenStruct.new({
                                    id: appointment[:id],
                                    appointment:,
                                    provider: unless appointment[:provider_service_id].nil?
                                                provider = provider_service.get_provider_service(
                                                  provider_id: appointment[:provider_service_id]
                                                )
                                                # Add the provider phone number from referral if available
                                                if referral_detail&.phone_number.present?
                                                  provider_with_phone = provider.to_h
                                                  provider_with_phone[:phone_number] = referral_detail.phone_number
                                                  OpenStruct.new(provider_with_phone)
                                                else
                                                  provider
                                                end
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

      def ccra_referral_service
        @ccra_referral_service ||= Ccra::ReferralService.new(current_user)
      end

      def provider
        provider_service.get_provider_service(provider_id: params[:provider_id])
      end
    end
  end
end
