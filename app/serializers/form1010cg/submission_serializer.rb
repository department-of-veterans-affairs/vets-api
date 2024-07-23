# frozen_string_literal: true

module Form1010cg
  class SubmissionSerializer
    include JSONAPI::Serializer

    set_id { '' }

    attribute :confirmation_number, &:carma_case_id
    attribute :submitted_at, &:accepted_at
  end
end
