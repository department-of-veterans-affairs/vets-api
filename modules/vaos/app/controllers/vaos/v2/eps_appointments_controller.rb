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

        referral_detail = fetch_referral_detail(appointment)
        provider = fetch_provider_with_phone(appointment, referral_detail)

        response = OpenStruct.new(
          id: appointment[:id],
          appointment:,
          provider:
        )

        render json: Eps::EpsAppointmentSerializer.new(response)
      end

      private

      ##
      # Retrieves referral details from CCRA service for the given appointment if a referral number is present.
      #
      # @param appointment [Hash] The appointment data containing referral information
      # @return [Ccra::ReferralDetail, nil] The referral details if found, nil otherwise
      def fetch_referral_detail(appointment)
        referral_number = appointment.dig(:referral, :referral_number)
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
      # Fetches provider information and enhances it with phone number from a referral if available.
      #
      # @param appointment [Hash] The appointment data containing provider service ID
      # @param referral_detail [Ccra::ReferralDetail, nil] The referral details potentially containing phone number
      # @return [Object, nil] Provider object enhanced with phone number if available, nil if no provider found
      def fetch_provider_with_phone(appointment, referral_detail)
        provider_id = appointment[:provider_service_id]
        return nil if provider_id.nil?

        provider = provider_service.get_provider_service(provider_id:)

        if referral_detail&.phone_number.present?
          provider_with_phone = provider.to_h
          provider_with_phone[:phone_number] = referral_detail.phone_number
          OpenStruct.new(provider_with_phone)
        else
          provider
        end
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
