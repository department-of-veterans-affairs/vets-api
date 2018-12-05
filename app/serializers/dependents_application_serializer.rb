# frozen_string_literal: true

class DependentsApplicationSerializer < ActiveModel::Serializer
  attribute(:guid)
  attribute(:state)
  attribute(:parsed_response)
end
