# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class EPSProviderService < VAOS::SessionService
      def get_appointment(appointment_id)
        with_monitoring do
          response = perform(:get, appointment_url(appointment_id), headers)
          OpenStruct.new(response.body)
        end
      end

      def create_appointment(patient_id, referral_number)
        with_monitoring do
          body = {
            patientId: patient_id,
            referral: {
              referralNumber: referral_number
            }
          }.to_json

          response = perform(:post, create_appointment_url, body, headers)
          OpenStruct.new(response.body)
        end
      end

      def submit_appointment(additional_patient_attributes, network_id, provider_service_id, referral_number, slot_ids)
        with_monitoring do
          body = {
            additionalPatientAttributes: additional_patient_attributes,
            networkId: network_id,
            providerServiceId: provider_service_id,
            referral: {
              referralNumber: referral_number
            },
            slotIds: slot_ids
          }.to_json

          response = perform(:post, submit_appointment_url, body, headers)
          OpenStruct.new(response.body)
        end
      end

      def calculate_drive_times(destinations, origin)
        with_monitoring do
          body = {
            destinations: destinations,
            origin: origin
          }.to_json

          response = perform(:post, drive_times_url, body, headers)
          OpenStruct.new(response.body)
        end
      end

      def get_provider_services
        with_monitoring do
          response = perform(:get, provider_services_url, headers)
          OpenStruct.new(response.body)
        end
      end

      def get_provider_service(provider_service_id)
        with_monitoring do
          response = perform(:get, provider_service_url(provider_service_id), headers)
          OpenStruct.new(response.body)
        end
      end

      def get_provider_service_slots(provider_service_id)
        with_monitoring do
          response = perform(:get, provider_service_slots_url(provider_service_id), headers)
          OpenStruct.new(response.body)
        end
      end

      def get_provider_service_slot(provider_service_id, slot_id)
        with_monitoring do
          response = perform(:get, provider_service_slot_url(provider_service_id, slot_id), headers)
          OpenStruct.new(response.body)
        end
      end

      private

      def appointment_url(appointment_id)
        "/care-navigation/v1/appointments/#{appointment_id}"
      end

      def create_appointment_url
        '/care-navigation/v1/appointments'
      end

      def submit_appointment_url
        '/care-navigation/v1/appointments/submit'
      end

      def drive_times_url
        '/care-navigation/v1/drive-times'
      end

      def provider_services_url
        '/care-navigations/v1/provider-services'
      end

      def provider_service_url(provider_service_id)
        "/care-navigations/v1/provider-services/#{provider_service_id}"
      end

      def provider_service_slots_url(provider_service_id)
        "/care-navigations/v1/provider-services/#{provider_service_id}/slots"
      end

      def provider_service_slot_url(provider_service_id, slot_id)
        "/care-navigations/v1/provider-services/#{provider_service_id}/slots/#{slot_id}"
      end
    end
  end
end