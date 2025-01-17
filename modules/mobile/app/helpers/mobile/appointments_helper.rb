# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  class AppointmentsHelper
    def initialize(user)
      @current_user = user
    end

    def create_new_appointment(params)
      appointment = post_appointment(params)
      backfill_location(appointment)
    end

    private

    def backfill_location(appointment)
      unless appointment[:clinic].nil?
        clinic = vaos_mobile_facility_service.get_clinic(appointment[:location_id], appointment[:clinic])
        appointment[:service_name] = clinic&.[](:service_name)
        appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
      end

      unless appointment[:location_id].nil?
        appointment[:location] =
          vaos_mobile_facility_service.get_facility(appointment[:location_id])
      end
      appointment
    end

    def post_appointment(params)
      appointments_service.post_appointment(create_params(params))
    end

    def appointments_service
      VAOS::V2::AppointmentsService.new(@current_user)
    end

    def vaos_mobile_facility_service
      VAOS::V2::MobileFacilityService.new(@current_user)
    end

    def create_params(params)
      base_params = %i[
        kind status location_id cancellable clinic comment reason service_type
        preferred_language minutes_duration patient_instruction priority
      ]

      nested_params = [
        reason_code: [:text, { coding: %i[system code display] }],
        slot: %i[id start end],
        contact: [telecom: %i[type value]],
        practitioner_ids: %i[system value],
        requested_periods: %i[start end],
        practitioners: practitioners_params,
        preferred_location: %i[city state],
        preferred_times_for_phone_call: [],
        telehealth: telehealth_params,
        extension: %i[desired_date]
      ]

      params.permit(*base_params, *nested_params)
    end

    def practitioners_params
      [
        :first_name,
        :last_name,
        :practice_name,
        {
          name: %i[family given]
        },
        {
          identifier: %i[system value]
        },
        {
          address: %i[type line city state postal_code country text]
        }
      ]
    end

    def telehealth_params
      [
        :url,
        :group,
        :vvs_kind,
        {
          atlas: [
            :site_code,
            :confirmation_code,
            {
              address: %i[
                street_address city state
                zip country latitude longitude
                additional_details
              ]
            }
          ]
        }
      ]
    end
  end
end
