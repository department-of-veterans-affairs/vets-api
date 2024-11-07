# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Observation < Common::Resource
      attribute :id, Types::String
      attribute :status, Types::String
      attribute :category, Types::Array do
        attribute :coding, Types::Array do
          attribute :system, Types::String
          attribute :code, Types::String
          attribute :display, Types::String
        end
        attribute :text, Types::String
      end
      attribute :code do
        attribute :coding, Types::Array do
          attribute :system, Types::String
          attribute :code, Types::String
          attribute :display, Types::String
        end
        attribute :text, Types::String
      end
      attribute :subject do
        attribute :reference, Types::String
        attribute :display, Types::String
      end
      attribute :effectiveDateTime, Types::DateTime
      attribute :issued, Types::DateTime
      attribute :performer, Types::Array do
        attribute :reference, Types::String
        attribute :display, Types::String
      end
      attribute :valueQuantity do
        attribute :value, Types::Float
        attribute :unit, Types::String
        attribute :system, Types::String
        attribute :code, Types::String
      end
    end
  end
end
