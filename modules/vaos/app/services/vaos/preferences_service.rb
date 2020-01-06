# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class PreferencesService < Common::Client::Base
    include Common::Client::Monitoring
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def get_preferences
      with_monitoring do
        response = perform(:get, url, nil, headers(user))
        OpenStruct.new(response.body.merge(id: preference_id))
      end
    end

    def put_preferences(request_object_body)
      with_monitoring do
        params = VAOS::PreferenceForm.new(user, request_object_body).params
        response = perform(:put, url, params, headers(user))
        OpenStruct.new(response.body.merge(id: preference_id))
      end
    end

    private

    # since preference doesn't have an id, but is a singular resource of patient/user we can just use user.uuid as id
    def preference_id
      user.uuid
    end

    def url
      "/var/VeteranAppointmentRequestService/v4/rest/patient/ICN/#{user.icn}/preference"
    end
  end
end
