# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class SystemsService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'
    AVAILABLE_APPT_FMT = '%m/%d/%Y'

    def initialize(user)
      @user = user
    end

    def get_systems
      with_monitoring do
        response = perform(:get, '/mvi/v1/patients/session/identifiers.json', nil, headers(@user))
        response.body.map { |system| OpenStruct.new(system) }
      end
    end

    def get_system_facilities(system_id, parent_code, type_of_care_id)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/institutions'
        url_params = {
          'facility-code' => system_id,
          'clinical-service' => type_of_care_id
        }
        url_params.merge!('parent-code' => parent_code) if parent_code.present?
        response = perform(:get, url, url_params, headers(@user))
        response.body.map do |system|
          institution = system.delete(:institution)
          OpenStruct.new(system.merge!(institution))
        end
      end
    end

    def get_facilities(facility_codes)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/parent-sites'
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, { 'facility-code' => facility_codes }, headers(@user), options)
        response.body.map { |facility| OpenStruct.new(facility) }
      end
    end

    def get_facility_clinics(facility_id, type_of_care_id, system_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/clinical-services/patient/ICN/#{@user.icn}/clinics"
        url_params = {
          'three-digit-code' => facility_id,
          'clinical-service' => type_of_care_id,
          'institution-code' => system_id
        }
        response = perform(:get, url, url_params, headers(@user))
        response.body.map { |clinic| OpenStruct.new(clinic) }
      end
    end

    def get_facility_limits(facility_id, type_of_care_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/#{@user.icn}/request-limit"
        url_params = {
          'institution-code' => facility_id,
          'clinical-service' => type_of_care_id
        }
        response = perform(:get, url, url_params, headers(@user))
        OpenStruct.new(response.body.merge!(id: facility_id))
      end
    end

    def get_cancel_reasons(facility_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{facility_id}" \
                "/patient/ICN/#{@user.icn}/cancel-reasons-list"
        response = perform(:get, url, nil, headers(@user))
        response.body[:cancel_reasons_list].map { |reason| OpenStruct.new(reason) }
      end
    end

    def get_facility_available_appointments(facility_id, start_date, end_date, clinic_ids)
      with_monitoring do
        url = available_appointments_url(facility_id)
        url_params = available_appointments_params(start_date, end_date, clinic_ids)
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, url_params, headers(@user), options)
        response.body.map { |fa| VAOS::FacilityAvailability.new(fa) }
      end
    end

    def get_system_pact(system_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{system_id}" \
                "/patient/ICN/#{@user.icn}/pact-team"
        response = perform(:get, url, nil, headers(@user))
        response.body.map { |pact| OpenStruct.new(pact) }
      end
    end

    def get_facility_visits(system_id, facility_id, type_of_care_id, schedule_type)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{system_id}" \
                "/patient/ICN/#{@user.icn}/#{schedule_type}-eligibility/visited-in-past-months"
        url_params = {
          'institution-code' => facility_id,
          'clinical-service' => type_of_care_id
        }
        response = perform(:get, url, url_params, headers(@user))
        OpenStruct.new(response.body.merge(id: SecureRandom.uuid))
      end
    end

    private

    def available_appointments_url(facility_id)
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{facility_id}" \
        "/patient/ICN/#{@user.icn}/available-appointment-slots"
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
