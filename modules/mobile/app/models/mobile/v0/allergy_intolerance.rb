# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance < Common::Resource
      attribute :id, Types::String
      attribute :resourceType, Types::String
      attribute :type, Types::String
      attribute :clinicalStatus, ClinicalStatus
      attribute :code, Code
      attribute :recordedDate, Types::DateTime
      attribute :patient, Patient
      attribute :recorder, Recorder
      attribute :notes, Types::Array.of(Note)
      attribute :reactions, Types::Array.of(Reaction)
    end
  end
end
