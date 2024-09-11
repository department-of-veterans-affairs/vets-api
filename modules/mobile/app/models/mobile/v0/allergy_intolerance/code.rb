# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance::Code < Common::Resource
      class Coding < Common::Resource
        attribute :system, Types::String
        attribute :code, Types::String
        attribute :display, Types::String
      end

      attribute :text, Types::String
      attribute :coding, Types::Array.of(Coding)
    end
  end
end
