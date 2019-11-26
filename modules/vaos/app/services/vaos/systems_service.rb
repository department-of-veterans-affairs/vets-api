# frozen_string_literal: true

require_relative '../vaos/concerns/headers'
# require_relative ''

module VAOS
  class SystemsService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'
    AVAILABLE_APPT_FMT = '%m/%d/%Y'

    def get_systems(user)
      with_monitoring do
        response = perform(:get, '/mvi/v1/patients/session/identifiers.json', nil, headers(user))
        response.body.map { |system| OpenStruct.new(system) }
      end
    end

    def get_facilities(user, facility_code)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/parent-sites'
        response = perform(:get, url, { 'facility-code' => facility_code }, headers(user))
        response.body.map { |facility| OpenStruct.new(facility) }
      end
    end

    def get_facility_clinics(user, facility_id, type_of_care_id, system_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/clinical-services/patient/ICN/#{user.icn}/clinics"
        url_params = {
          'three-digit-code' => facility_id,
          'clinical-service' => type_of_care_id,
          'institution-code' => system_id
        }
        response = perform(:get, url, url_params, headers(user))
        response.body.map { |clinic| OpenStruct.new(clinic) }
      end
    end

    def get_cancel_reasons(user, facility_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{facility_id}" \
                "/patient/ICN/#{user.icn}/cancel-reasons-list"
        response = perform(:get, url, nil, headers(user))
        response.body.map { |reason| OpenStruct.new(reason) }
      end
    end

    def get_facility_available_appointments(user, facility_id, start_date, end_date, clinic_ids)
      with_monitoring do
        url = available_appointments_url(user.icn, facility_id)
        url_params = available_appointments_params(start_date, end_date, clinic_ids)
        response = perform(:get, url, url_params, headers(user))
        response.body.map { |fa| VAOS::FacilityAvailability.new(fa) }
      end
    end

    private

    def available_appointments_url(icn, facility_id)
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{facility_id}" \
        "/patient/ICN/#{icn}/available-appointment-slots"
    end

    def available_appointments_params(start_date, end_date, clinic_ids)
      {
        startDate: start_date.strftime(AVAILABLE_APPT_FMT),
        endDate: end_date.strftime(AVAILABLE_APPT_FMT),
        clinicIds: clinic_ids
      }
    end
  end
end
