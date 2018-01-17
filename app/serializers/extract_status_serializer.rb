# frozen_string_literal: true

class ExtractStatusSerializer < ActiveModel::Serializer
  attribute :id
  attribute :extract_type
  attribute :last_updated
  attribute :status
  attribute :created_on
  attribute :station_number
end
