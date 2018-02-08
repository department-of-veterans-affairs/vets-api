# frozen_string_literal: true

class VICSubmissionSerializer < ActiveModel::Serializer
  attribute(:guid)
  attribute(:state)
  attribute(:response)
end
