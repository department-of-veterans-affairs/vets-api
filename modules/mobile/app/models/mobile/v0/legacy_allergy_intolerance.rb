# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class LegacyAllergyIntolerance < Common::Resource
      attribute :id, Types::String
      attribute :resourceType, Types::String
      attribute :type, Types::String
      attribute :clinicalStatus, Types::Hash
      attribute :code, Types::Hash
      attribute :recordedDate, Types::DateTime
      attribute :patient, Types::Hash
      attribute :recorder, Types::Hash
      attribute :notes, Types::Array
      attribute :reactions, Types::Array
      attribute :category, Types::Array.of(Types::String)
    end
  end
end
