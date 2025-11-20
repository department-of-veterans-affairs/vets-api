# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Allergy
    include Vets::Model

    attribute :id, String
    attribute :name, String
    attribute :date, String # Pass on as-is to the frontend
    attribute :categories, String, array: true
    attribute :reactions, String, array: true
    attribute :location, String
    attribute :observedHistoric, String # 'o' or 'h' or nil
    attribute :notes, String, array: true
    attribute :provider, String
  end
end
