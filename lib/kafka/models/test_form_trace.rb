# frozen_string_literal: true

require 'active_model'

module Kafka
  class TestFormTrace
    include ActiveModel::API
    include ActiveModel::Attributes

    attribute :data

    validates :data, presence: true
    validate :data_values_are_strings

    private

    def data_values_are_strings
      return true if data.blank?

      unless data.is_a?(Hash) && data.values.all? { |v| v.is_a?(String) }
        errors.add(:data, 'must be a hash with all string values')
      end
    end
  end
end
