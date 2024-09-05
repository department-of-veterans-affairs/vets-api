# frozen_string_literal: true

class SubmissionSerializer
  include JSONAPI::Serializer

  attribute :education_benefit

  set_id { '' }
end
