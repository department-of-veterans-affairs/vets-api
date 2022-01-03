# frozen_string_literal: true

class SubmissionSerializer < ActiveModel::Serializer
  attribute :education_benefit

  def id
    nil
  end
end
