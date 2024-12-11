# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance < Common::Resource
      attribute :id, Types::String
      attribute :resourceType, Types::String
      attribute :type, Types::String
      attribute :category, Types::Array.of(Types::String)
      attribute :clinicalStatus do
        attribute :coding, Types::Array do
          attribute :system, Types::String
          attribute :code, Types::String
        end
      end

      attribute :code do
        attribute :text, Types::String
        attribute :coding, Types::Array do
          attribute :system, Types::String
          attribute :code, Types::String
          attribute :display, Types::String
        end
      end

      attribute :recordedDate, Types::DateTime
      attribute :patient do
        attribute :reference, Types::String
        attribute :display, Types::String
      end

      attribute :recorder do
        attribute :reference, Types::String
        attribute :display, Types::String
      end

      attribute :notes, Types::Array do
        attribute :time, Types::DateTime
        attribute :text, Types::String
        attribute :author_reference do
          attribute :reference, Types::String
          attribute :display, Types::String
        end
      end

      attribute :reactions, Types::Array do
        attribute :substance do
          attribute :text, Types::String
          attribute :coding, Types::Array do
            attribute :system, Types::String
            attribute :code, Types::String
            attribute :display, Types::String
          end
        end

        attribute :manifestation, Types::Array do
          attribute :text, Types::String
          attribute :coding, Types::Array do
            attribute :system, Types::String
            attribute :code, Types::String
            attribute :display, Types::String
          end
        end
      end
    end
  end
end
