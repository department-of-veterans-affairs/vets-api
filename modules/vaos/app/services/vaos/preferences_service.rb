# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class PreferencesService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_preferences(user)
      with_monitoring do
        url = "/var/VeteranAppointmentRequestService/v4/rest/patient/ICN/#{user.icn}/preference"
        response = perform(:get, url, nil, headers(user))
        OpenStruct.new(response.body.merge(id: SecureRandom.uuid))
      end
    end
  end
end
