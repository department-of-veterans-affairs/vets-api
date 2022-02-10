# frozen_string_literal: true

class EnrollmentSerializer < ActiveModel::Serializer
  attribute :enrollment

  def id
    nil
  end
end
