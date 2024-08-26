# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Appeal < Common::Resource
        AOJ_TYPES = Types::String.enum(
          'vba',
          'vha',
          'nca',
          'other'
        )

        LOCATION_TYPES = Types::String.enum(
          'aoj',
          'bva'
        )

        PROGRAM_AREA_TYPES = Types::String.enum(
          'compensation',
          'pension',
          'insurance',
          'loan_guaranty',
          'education',
          'vre',
          'medical',
          'burial',
          'bva',
          'other',
          'multiple'
        )

        attribute :id, Types::String
        attribute :appealIds, Types::Array.of(Types::String)
        attribute :active, Types::Bool
        attribute :alerts, Types::Array.of(Appeals::Alert)
        attribute :aod, Types::Bool.optional
        attribute :aoj, AOJ_TYPES
        attribute :description, Types::String
        attribute :docket, Appeals::Docket.optional
        attribute :events, Types::Array.of(Appeals::Event)
        attribute :evidence, Types::Array.of(Appeals::Evidence).optional
        attribute :incompleteHistory, Types::Bool
        attribute :issues, Types::Array.of(Appeals::Issue)
        attribute :location, LOCATION_TYPES
        attribute :programArea, PROGRAM_AREA_TYPES
        attribute :status, Appeals::Status
        attribute :type, Types::String
        attribute :updated, Types::DateTime
      end
    end
  end
end
