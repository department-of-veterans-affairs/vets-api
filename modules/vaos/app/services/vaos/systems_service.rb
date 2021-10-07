# frozen_string_literal: true

module VAOS
  class SystemsService < VAOS::SessionService
    AVAILABLE_APPT_FMT = '%m/%d/%Y'

    def get_systems
      with_monitoring do
        response = perform(:get, '/mvi/v1/patients/session/identifiers.json', nil, headers)
        response
          .body
          .select { |system| system[:assigning_authority].include?('dfn-') || system[:assigning_code].include?('CRNR') }
          .map { |system| OpenStruct.new(system) }
      end
    end

    def get_system_facilities(system_id, parent_code, type_of_care_id)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/institutions'
        url_params = {
          'facility-code' => system_id,
          'clinical-service' => type_of_care_id,
          'parent-code' => parent_code
        }
        response = perform(:get, url, url_params, headers)
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
        response = perform(:get, url, { 'facility-code' => facility_codes }, headers, options)
        response.body.map { |facility| OpenStruct.new(facility) }
      end
    end

    def get_facility_clinics(facility_id, type_of_care_id, system_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/clinical-services/patient/ICN/#{@user.icn}/clinics"
        url_params = {
          'three-digit-code' => system_id,
          'clinical-service' => type_of_care_id,
          'institution-code' => facility_id
        }
        response = perform(:get, url, url_params, headers)
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
        response = perform(:get, url, url_params, headers)
        OpenStruct.new(response.body.merge!(id: facility_id))
      end
    end

    def get_facilities_limits(facility_ids, type_of_care_id)
      with_monitoring do
        url = get_facilities_limits_url
        url_params = {
          'institution-code' => facility_ids,
          'clinical-service' => type_of_care_id
        }
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, url_params, headers, options)
        response.body.map { |facility| OpenStruct.new(facility) }
      end
    end

    def get_cancel_reasons(facility_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{facility_id}" \
              "/patient/ICN/#{@user.icn}/cancel-reasons-list"
        response = perform(:get, url, nil, headers)
        response.body[:cancel_reasons_list].map { |reason| OpenStruct.new(reason) }
      end
    end

    def get_facility_available_appointments(facility_id, start_date, end_date, clinic_ids)
      with_monitoring do
        url = available_appointments_url(facility_id)
        url_params = available_appointments_params(start_date, end_date, clinic_ids)
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, url_params, headers, options)
        response.body.map { |fa| VAOS::FacilityAvailability.new(fa) }
      end
    end

    def get_system_pact(system_id)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/site/#{system_id}" \
              "/patient/ICN/#{@user.icn}/pact-team"
        response = perform(:get, url, nil, headers)
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
        response = perform(:get, url, url_params, headers)
        OpenStruct.new(response.body.merge(id: SecureRandom.uuid))
      end
    end

    def get_clinic_institutions(system_id, clinic_ids)
      with_monitoring do
        url = "/cdw/v3/facilities/#{system_id}/clinics"
        # the vaos clinic ids endpoint doesn't follow the url_param[]=1&url_param[]=2 style of passing an array
        url_params = {
          'pageSize' => 0,
          'clinicIds' => [*clinic_ids].join(',')
        }
        response = perform(:get, url, url_params, headers)
        response.body[:data].map { |clinic| VAOS::ClinicInstitution.new(clinic) }
      end
    end

    def get_request_eligibility_criteria(site_codes: nil, parent_sites: nil)
      with_monitoring do
        url = '/facilities/v1/request-eligibility-criteria'
        url_params = nil
        if site_codes || parent_sites
          url_params = {}
          url_params['site-codes'] = site_codes if site_codes
          url_params['parent-sites'] = parent_sites if parent_sites
        end
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, url_params, headers, options)
        response.body.map { |rec| OpenStruct.new(rec) }
      end
    end

    def get_direct_booking_elig_crit(site_codes: nil, parent_sites: nil)
      with_monitoring do
        url = '/facilities/v1/direct-booking-eligibility-criteria'
        url_params = nil
        if site_codes || parent_sites
          url_params = {}
          url_params['site-codes'] = site_codes if site_codes
          url_params['parent-sites'] = parent_sites if parent_sites
        end
        options = { params_encoder: Faraday::FlatParamsEncoder }
        response = perform(:get, url, url_params, headers, options)
        response.body.map { |rec| OpenStruct.new(rec) }
      end
    end

    private

    def get_facilities_limits_url
      "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/#{@user.icn}/request-limits"
    end

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
