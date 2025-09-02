# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Condition
    include Vets::Model

    attribute :id, String
    attribute :date, String
    attribute :name, String
    attribute :provider, String
    attribute :facility, String
    attribute :comments, Array
  end
end
