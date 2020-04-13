# frozen_string_literal: true

module VAOS
  class PreferencesService < VAOS::BaseService
    def get_preferences
      with_monitoring do
        response = perform(:get, url, nil, headers)
        OpenStruct.new(response.body.merge(id: preference_id))
      end
    end

    def put_preferences(request_object_body)
      with_monitoring do
        params = VAOS::PreferenceForm.new(user, request_object_body).params
        response = perform(:put, url, params, headers)
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
