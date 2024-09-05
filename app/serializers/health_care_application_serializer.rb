# frozen_string_literal: true

class HealthCareApplicationSerializer
  include JSONAPI::Serializer

  set_type :health_care_applications

  attributes :state, :form_submission_id, :timestamp
end
