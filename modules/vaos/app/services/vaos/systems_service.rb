# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class SystemsService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_systems(user)
      with_monitoring do
        response = perform(:get, '/mvi/v1/patients/session/identifiers.json', nil, headers(user))
        response.body.map { |system| OpenStruct.new(system) }
      end
    end

    def get_system_facilities(user, system_id, parent_code, type_of_care_id)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/institutions'
        url_params = {
          'facility-code' => system_id,
          'parent-code' => parent_code,
          'clinical-service' => type_of_care_id
        }
        response = perform(:get, url, url_params, headers(user))
        response.body.map do |system|
          institution = system.delete(:institution)
          OpenStruct.new(system.merge!(institution))
        end
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
        response.body[:cancel_reasons_list].map { |reason| OpenStruct.new(reason) }
      end
    end
  end
end
