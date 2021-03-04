# frozen_string_literal: true

module HealthQuest
  module Resource
    module ClientModel
      class Patient
        include Shared::IdentityMetaInfo

        NAME_USE = 'official'

        attr_reader :data, :model, :identifier, :meta, :user

        def self.manufacture(data, user)
          new(data, user)
        end

        def initialize(data, user)
          @data = data || {}
          @model = ::FHIR::Patient.new
          @user = user
          @identifier = ::FHIR::Identifier.new
          @meta = ::FHIR::Meta.new
        end

        def prepare
          model.tap do |p|
            p.name = name
            p.identifier = set_identifiers
            p.meta = set_meta
          end
        end

        def name
          [{
            use: NAME_USE,
            family: [user.last_name],
            given: [user.first_name]
          }]
        end

        def identifier_value
          user.icn
        end

        def identifier_code
          'ICN'
        end
      end
    end
  end
end
