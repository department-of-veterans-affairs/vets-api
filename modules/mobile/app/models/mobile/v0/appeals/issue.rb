# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Issue < Common::Resource
        LAST_ACTION_TYPES = Types::String.enum(
          'field_grant',
          'withdrawn',
          'allowed',
          'denied',
          'remand',
          'cavc_remand'
        )

        attribute :active, Types::Bool
        attribute :lastAction, LAST_ACTION_TYPES.optional
        attribute :description, Types::String
        attribute :diagnosticCode, Types::String.optional
        attribute :date, Types::Date
      end
    end
  end
end
