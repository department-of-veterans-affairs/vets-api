# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointmentsController < VAOS::BaseController
      def show
        appointment_data = appointment_service.get_appointment(
          appointment_id: eps_appointment_id,
          retrieve_latest_details: true
        )

        raise Common::Exceptions::RecordNotFound, message: 'Record not found' if appointment_data[:state] == 'draft'

        response_object = assemble_appt_response_object(appointment_data)
        render json: response_object
      end

      private

      ##
      # Assembles a structured response object for an EPS appointment by:
      # 1. Fetching referral details if a referral number exists
      # 2. Fetching provider information if a provider service ID exists
      # 3. Creating a comprehensive EpsAppointment object with all related data
      # 4. Serializing the appointment object
      #
      # @param appointment_data [Hash] Raw appointment data from the EPS service
      # @return [Eps::EpsAppointmentSerializer] Serialized appointment with referral and provider data
      def assemble_appt_response_object(appointment_data)
        referral_detail = fetch_referral_detail(appointment_data)
        provider = fetch_provider(appointment_data)
        eps_appointment = VAOS::V2::EpsAppointment.new(appointment_data, referral_detail, provider)

        Eps::EpsAppointmentSerializer.new(eps_appointment)
      end

      ##
      # Retrieves referral details from CCRA service for the given appointment if a referral number is present.
      #
      # @param appointment_data [Hash] The appointment data containing referral information
      # @return [Ccra::ReferralDetail, nil] The referral details if found, nil otherwise
      def fetch_referral_detail(appointment_data)
        referral_number = appointment_data.dig(:referral, :referral_number)
        return nil if referral_number.blank?

        begin
          # TODO: Need correct mode parameter, this one is hard-coded based on examples
          ccra_referral_service.get_referral(referral_number, '2')
        rescue => e
          Rails.logger.error "Failed to retrieve referral details: #{e.message}"
          nil
        end
      end

      ##
      # Fetches provider information for the given appointment.
      #
      # @param appointment_data [Hash] The appointment data containing provider service ID
      # @return [Object, nil] Provider object or nil if no provider ID is found
      def fetch_provider(appointment_data)
        provider_id = appointment_data[:provider_service_id]
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

      def ccra_referral_service
        @ccra_referral_service ||= Ccra::ReferralService.new(current_user)
      end

      def provider
        provider_service.get_provider_service(provider_id: params[:provider_id])
      end
    end
  end
end
