# frozen_string_literal: true

module MyHealth
  module V1
    class ExtractStatusSerializer < ActiveModel::Serializer
      attribute :id
      attribute :extract_type
      attribute :last_updated
      attribute :status
      attribute :created_on
      attribute :station_number
    end
  end
end
