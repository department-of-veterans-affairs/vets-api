# frozen_string_literal: true

module Form1010cg
  class SubmissionSerializer < ActiveModel::Serializer
    attribute(:confirmation_number) { object.carma_case_id }
    attribute(:submitted_at) { object.submitted_at }

    def id
      nil
    end
  end
end
