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
  end
end
