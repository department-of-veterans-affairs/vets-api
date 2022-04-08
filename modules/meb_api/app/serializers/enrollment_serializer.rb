# frozen_string_literal: true

class EnrollmentSerializer < ActiveModel::Serializer
  attribute :enrollment_verifications

  def id
    nil
  end
end
