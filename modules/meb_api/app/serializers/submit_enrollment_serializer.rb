# frozen_string_literal: true

class SubmitEnrollmentSerializer < ActiveModel::Serializer
  attribute :enrollment_certify_responses

  def id
    nil
  end
end
