# frozen_string_literal: true

class SubmitEnrollmentSerializer
  include JSONAPI::Serializer

  attribute :enrollment_certify_responses

  set_id { '' }
end
