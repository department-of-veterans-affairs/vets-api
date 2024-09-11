# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance::Reaction < Common::Resource
      class Substance < Common::Resource
        class Coding < Common::Resource
          attribute :system, Types::String
          attribute :code, Types::String
          attribute :display, Types::String
        end

        attribute :coding, Types::Array.of(Coding)
        attribute :text, Types::String
      end

      class Manifestation < Common::Resource
        class Coding < Common::Resource
          attribute :system, Types::String
          attribute :code, Types::String
          attribute :display, Types::String
        end

        attribute :coding, Types::Array.of(Coding)
        attribute :text, Types::String
      end

      attribute :substance, Substance
      attribute :manifestation, Types::Array.of(Manifestation)
    end
  end
end
