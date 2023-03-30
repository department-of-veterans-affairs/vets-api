# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  module V0
    module VAOSAppointments
      class AppointmentsHelper
        def initialize(user)
          @current_user = user
        end

        def create_new_appointment(params)
          appointment = post_appointment(params)
          backfill_location(appointment)
        end

        def backfill_location(appointment)
          unless appointment[:clinic].nil?
            clinic = get_clinic(appointment[:location_id], appointment[:clinic])
            appointment[:service_name] = clinic&.[](:service_name)
            appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          end

          appointment[:location] = get_facility(appointment[:location_id]) unless appointment[:location_id].nil?
          appointment
        end

        def get_clinic(location_id, clinic_id)
          clinics = systems_service.get_facility_clinics(location_id:, clinic_ids: clinic_id)
          clinics.first unless clinics.empty?
        rescue Common::Exceptions::BackendServiceException
          Rails.logger.error(
            "Error fetching clinic #{clinic_id} for location #{location_id}",
            clinic_id:,
            location_id:
          )
        end

        def get_facility(location_id)
          mobile_facility_service.get_facility(location_id)
        rescue Common::Exceptions::BackendServiceException
          Rails.logger.error(
            "Error fetching facility details for location_id #{location_id}",
            location_id:
          )
        end

        private

        def post_appointment(params)
          appointments_service.post_appointment(create_params(params))
        end

        def appointments_service
          VAOS::V2::AppointmentsService.new(@current_user)
        end

        def systems_service
          VAOS::V2::SystemsService.new(@current_user)
        end

        def mobile_facility_service
          VAOS::V2::MobileFacilityService.new(@current_user)
        end

        # rubocop:disable Metrics/MethodLength
        def create_params(params)
          params.permit(:kind,
                        :status,
                        :location_id,
                        :cancellable,
                        :clinic,
                        :comment,
                        :reason,
                        :service_type,
                        :preferred_language,
                        :minutes_duration,
                        :patient_instruction,
                        :priority,
                        reason_code: [
                          :text, { coding: %i[system code display] }
                        ],
                        slot: %i[id start end],
                        contact: [telecom: %i[type value]],
                        practitioner_ids: %i[system value],
                        requested_periods: %i[start end],
                        practitioners: [
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
                        ],
                        preferred_location: %i[city state],
                        preferred_times_for_phone_call: [],
                        telehealth: [
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
                        ],
                        extension: %i[desired_date])
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
