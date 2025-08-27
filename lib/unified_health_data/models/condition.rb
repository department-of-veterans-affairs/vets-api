# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class ConditionAttributes
    include Vets::Model

    attribute :date, String
    attribute :name, String
    attribute :provider, String
    attribute :facility, String
    attribute :comments, String
  end

  class Condition
    include Vets::Model

    attribute :id, String
    attribute :type, String
    attribute :attributes, UnifiedHealthData::ConditionAttributes, array: false
  end
end
