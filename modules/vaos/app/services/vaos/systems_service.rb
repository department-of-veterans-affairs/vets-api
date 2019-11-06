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
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    def get_facilities(user)
      with_monitoring do
        url = '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/parent-sites'
        response = perform(:get, url, { 'facility-code' => 688}, headers(user))
        response.body.map { |facility| OpenStruct.new(facility) }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end
  end
end
