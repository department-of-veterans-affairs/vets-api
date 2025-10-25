# frozen_string_literal: true

module VAOS
  module V2
    class EpsAppointment
      COMMUNITY_CARE_APPOINTMENT = 'COMMUNITY_CARE_APPOINTMENT'
      COMMUNITY_CARE_REQUEST = 'COMMUNITY_CARE_REQUEST'

      attr_reader :id, :status, :patient_icn, :created, :location_id, :clinic,
                  :start, :is_latest, :last_retrieved, :contact, :referral_id,
                  :referral, :provider_service_id, :provider_name,
                  :provider, :modality, :location, :past

      def initialize(appointment_data = {}, provider = nil)
        appointment_details = appointment_data[:appointment_details]
        referral_details = appointment_data[:referral]

        @id = appointment_data[:id]&.to_s
        @status = determine_status(appointment_details&.dig(:status))
        @patient_icn = appointment_data[:patient_id]
        @created = appointment_details&.dig(:last_retrieved)
        @location_id = appointment_data[:network_id]
        @clinic = appointment_data[:provider_service_id]
        @start = appointment_details&.dig(:start)
        @is_latest = appointment_details&.dig(:is_latest)
        @last_retrieved = appointment_details&.dig(:last_retrieved)
        @contact = appointment_data[:contact]
        @referral_id = referral_details&.dig(:referral_number)
        @referral = { referral_number: referral_details&.dig(:referral_number)&.to_s }
        @provider_service_id = appointment_data[:provider_service_id]
        @provider = provider
        @provider_name = provider&.[](:name).presence || 'unknown'
        @modality = 'communityCareEps'
        @location = build_location_data
        @past = past_appointment?
      end

      def serializable_hash
        base_hash = {
          id: @id, status: @status, patient_icn: @patient_icn, created: @created,
          location_id: @location_id, clinic: @clinic, start: @start, contact: @contact,
          referral_id: @referral_id, referral: @referral,
          provider_service_id: @provider_service_id, provider_name: @provider_name,
          kind: 'cc', modality: @modality, type: eps_type,
          pending: request_type?, past: @past, future: future_appointment?
        }

        base_hash[:location] = @location if @location.present?

        base_hash.compact
      end

      def provider_details
        return nil if provider.nil?

        result = {
          id: provider[:id],
          name: provider[:name],
          practice: extract_practice,
          location: provider[:location],
          phone: extract_phone_number
        }

        result.compact
      end

      private

      def extract_practice
        provider_org = provider&.[](:provider_organization)
        return nil if provider_org.blank?

        provider_org[:name]
      end

      def extract_phone_number
        contact_details = provider&.[](:contact_details)
        return nil if contact_details.blank?

        # Filter to phone entries only
        phone_contacts = contact_details.select { |c| c[:system] == 'phone' }
        return nil if phone_contacts.blank?

        # Find contact with use == 'for_patient', or use the first phone contact
        contact = phone_contacts.find { |c| c[:use] == 'for_patient' } || phone_contacts.first
        contact&.dig(:value)
      end

      def build_location_data
        return nil if @provider.nil? || @provider[:location].nil?

        location = @provider[:location]
        {
          id: @provider_service_id,
          type: 'appointments',
          attributes: {
            name: location[:name],
            timezone: {
              timeZoneId: location[:timezone].presence || 'UTC'
            }
          }
        }
      end

      def determine_status(status)
        status == 'booked' ? 'booked' : 'proposed'
      end

      def eps_type
        @start.present? ? COMMUNITY_CARE_APPOINTMENT : COMMUNITY_CARE_REQUEST
      end

      def request_type?
        %w[REQUEST COMMUNITY_CARE_REQUEST].include?(eps_type)
      end

      def past_appointment?
        return nil if @start.blank?

        # Community care follows the non-telehealth rule (+60 minutes grace window)
        (@start.to_datetime + 60.minutes) < Time.now.utc
      end

      def future_appointment?
        return false if @start.blank?

        !request_type? && !past_appointment?
      end
    end
  end
end
